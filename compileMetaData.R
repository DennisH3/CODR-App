# Compile all the metadata files into 1 master file

library(tidyverse)
library(data.table)
library(arrow)

# Empty list to store each dataframe
mds = list()

# Get list of all CODR tables
files <- list.files("./CODR_tables")

# Check that files is non-empty
if(length(files) > 0){
  
  # Check if allMetaData.parquet exists
  if(file.exists("./allMetaData.parquet")){
    
    # Load allMetaData.parquet
    allMD <- read_parquet("./allMetaData.parquet")
    
    # Append allMD to the front of the mds list
    mds <- append(allMD, mds, after=1)
    
    # Get just productIds
    df <- allMD$productId
    
    # Convert them to integer and extract the productId
    file_pids <- as.integer(str_sub(files, 1, 8))
    
    # Assign pids to be the remaining productIds that have not been binded
    pids <- df[which(!(df %in% file_pids))]
    
    # Read the files that have not been binded
    for (i in 1:length(pids)){
      
      # Append the CODR table meta data to the end of the mds list
      mds <- append(mds, list(read_parquet(str_glue("./CODR_tables/{pids[i]}.parquet"))))
    }
    
    # Bind mds into one data frame
    allMD <- rbindlist(mds, use.names = TRUE, fill=TRUE)
    
    # Remove duplicates
    allMD <- allMD %>% distinct()
    
    # Select columns
    allMD <- allMD %>% select(productId, cansimId, cubeTitleEn, cubeTitleFr, cubeStartDate,
                              cubeEndDate, releaseTime, dimensionNameEn, dimensionNameFr,
                              memberNameEn, memberNameFr, memberUomEn, memberUomFr,
                              subjectEn, subjectFr, surveyEn, surveyFr, frequencyDescEn,
                              frequencyDescFr, footnotesEn, footnotesFr, classificationTypeEn,
                              classificationTypeFr, archiveStatusEn, archiveStatusFr)
    
    # Save the final data set
    fwrite(allMD, "allMetaData.csv.gz")
  } else {
    
    # Read all CODR meta data
    for (i in 1:length(files)){
      
      # Append the CODR table meta data to the end of the mds list
      mds <- append(mds, list(read_parquet(str_glue("./CODR_tables/{files[i]}"))))
    }
    
    # Bind mds into one data frame
    allMD <- rbindlist(mds, use.names = TRUE, fill=TRUE)
    
    # Remove duplicates
    allMD <- allMD %>% distinct()
    
    # Select columns
    allMD <- allMD %>% select(productId, cansimId, cubeTitleEn, cubeTitleFr, cubeStartDate,
                              cubeEndDate, releaseTime, dimensionNameEn, dimensionNameFr,
                              memberNameEn, memberNameFr, memberUomEn, memberUomFr,
                              subjectEn, subjectFr, surveyEn, surveyFr, frequencyDescEn,
                              frequencyDescFr, footnotesEn, footnotesFr, classificationTypeEn,
                              classificationTypeFr, archiveStatusEn, archiveStatusFr)
    
    # Save the final data set
    fwrite(allMD, "allMetaData.csv.gz")
  }
} else {
  print("There are no CODR metadata files to bind")
}

# Print column names
# This is to easily select which columns should be kept when using the cansimApp.R
print(colnames(allMD))
