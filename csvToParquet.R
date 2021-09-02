# Convert metadata csv to parquet
# Took 12 mins to convert 5897 csvs to parquet
# Went from 27.84 GB to 217 MB

library(data.table)
library(arrow)

# Get file names
files <- list.files("./CODR_tables")

# Read all CODR meta data
for (i in 1:length(files)){
  
  # Read csv
  df <- fread((paste0("./CODR_tables/", files[i])))
  
  # Write parquet
  write_parquet(df, paste0("./CODR_tables/", str_sub(files[i], 1, 8), ".parquet"))
  
  # Delete the csv
  file.remove(paste0("./CODR_tables/", files[i]))
  
  # Print how many tables are remaining
  print(str_glue("Progress: {(i/length(files))*100}% complete. {i} out of {length(filess)} converted"))
}