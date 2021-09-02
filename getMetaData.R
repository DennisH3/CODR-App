# Download metadata for all productIds

library(tidyverse)
library(data.table)
library(arrow)
library(httr)
library(jsonlite)
library(curl) # Note: I had to conda install curl because there was an error with curl to fetch the url

# Get the metadata and transform it into a dataframe
# Input: pid - product ID as an int
# Output: md - dataframe with all the meta data
getMetaData <- function(pid){
  url <- "https://www150.statcan.gc.ca/t1/wds/rest/getCubeMetadata"
  body <- list(list("productId" = pid))
  
  # Get the metadata
  metaData <- POST(url, body = body, encode = "json")
  
  # Retrieves the contents of metaData as JSON
  md <- jsonlite::fromJSON(content(metaData, as = "text", encoding = "UTF-8"), flatten = TRUE)
  
  # Drop some columns
  md <- select(md, -status, -object.responseStatusCode, -object.archiveStatusCode,
               -object.correctionFootnote, -object.correction)
  
  # Remove object. in the column names
  names(md) <- gsub("object.", "", names(md))
  
  # Unnest the columns with dataframes
  md <- unnest(md, dimension, keep_empty = TRUE)
  md <- unnest(md, member, keep_empty = TRUE)
  
  # Check if footnote column is a column of empty lists
  if(all(lengths(md$footnote) == 0)){
    
    # If it is, replace the column with NAs
    md$footnote <- NA
  } else {
    
    # Else, unnest it
    md <- unnest(md, footnote, keep_empty = TRUE)
  }
  
  # Unnest columns with lists
  md <- unnest(md, subjectCode, keep_empty = TRUE)
  md <- unnest(md, surveyCode, keep_empty = TRUE)
  
  # Keep all columns that are not all NAs
  md <- md[colSums(!is.na(md)) > 0]
  
  return(md)
}

########################## MAIN ##########################
# Url for getAllCubesList
url <- GET("https://www150.statcan.gc.ca/t1/wds/rest/getAllCubesList")

# Retrieves the contents of url as JSON
df <- jsonlite::fromJSON(content(url, as = "text", encoding = "UTF-8"), flatten = TRUE)

# Get the list of productIds
df <- df$productId

# Check for already downloaded CODR tables
if(file.exists("./downloaded_pids.csv")){
  
  # Read the file
  files <- fread("./downloaded_pids.csv")
  
  # Convert to vector
  files <- files$V1
  
  # Assign pids to be the remaining productIds that have not been downloaded
  pids <- df[which(!(df %in% files))]
  
}

# If CODR_tables folder does not exist
if(dir.exists("./CODR_tables") == FALSE){
  
  # Create the subfolder to store downloaded CODR Tables
  dir.create("./CODR_tables")
}

# Get code sets
# Url for code sets
url <- GET("https://www150.statcan.gc.ca/t1/wds/rest/getCodeSets")

# Retrieves the contents of url as JSON
codes <- jsonlite::fromJSON(content(url, as = "text", encoding = "UTF-8"), flatten = TRUE)

# Extract code sets
codes <- codes$object

# Check if pid is non-empty
if(length(pids) > 0){
  # For each productId, get its meta data
  for (i in 1:length(pids)){
    
    # Get the meta data
    md <- getMetaData(pids[i])
    
    # Check if geoAttribute is in md
    if("geoAttribute" %in% colnames(md)){
      
      # Check if it is a column of empty lists
      if(all(lengths(md$geoAttribute) == 0 & is.list(md$geoAttribute))){
        
        # If it is, replace the column with NAs
        md$geoAttribute <- NA
      } else {
        
        # Else, unnest it
        md <- unnest(md, geoAttribute, keep_empty = TRUE)
      }
    }
    
    # Check if classificationTypeCode is in md
    if ("classificationTypeCode" %in% colnames(md)){
      
      # Convert classificationTypeCode to integer
      md$classificationTypeCode <- as.integer(md$classificationTypeCode)
      
      # Merge with code set
      md <- left_join(md, codes$classificationType, by = "classificationTypeCode")
    }
    
    # Merge with code sets
    if("subjectCode" %in% colnames(md)){
      md <- left_join(md, codes$subject, by = "subjectCode")
    }
    
    if("surveyCode" %in% colnames(md)){
      md <- left_join(md, codes$survey, by = "surveyCode")
    }
    
    if("frequencyCode" %in% colnames(md)){
      md <- left_join(md, codes$frequency, by = "frequencyCode")
    }
    
    if("memberUomCode" %in% colnames(md)){
      md <- left_join(md, codes$uom, by = "memberUomCode")
    }
    
    # Drop duplicates
    md <- distinct(md)
    
    # Sort column names to keep related columns together
    md <- select(md, sort(names(md)))
    
    # Check if there is a cansimId
    if("cansimId" %in% colnames(md)){
      
      # Move productId and cansimId to the front
      md <- select(md, productId, cansimId, everything())
    } else {
      
      # Move productId to the front
      md <- select(md, productId, everything())
    }
    
    # Extract just the dates from releaseTime
    md$releaseTime <- str_sub(md$releaseTime, 1, 10)
    
    # Convert date columns from chr to date
    md$cubeStartDate <- as.Date(md$cubeStartDate)
    md$cubeEndDate <- as.Date(md$cubeEndDate)
    md$releaseTime <- as.Date(md$releaseTime)
    
    # Keep all columns that are not all NAs
    md <- md[colSums(!is.na(md)) > 0]
    
    # Save the meta data to a parquet
    write_parquet(md, file = str_glue("./CODR_tables/{pids[i]}.parquet"))
    
    # Add downloaded pid to files
    files <- append(files, pids[i])
    
    # Update downloaded_pids
    fwrite(list(files), "downloaded_pids.csv")
    
    # Print how many tables are remaining
    print(str_glue("Progress: {(i/length(pids))*100}% complete. {i} out of {length(pids)} downloaded"))
    
    # Wait for 10 seconds
    Sys.sleep(10)
  }
} else {
  print("There are no new CODR metadata tables to download")
}
