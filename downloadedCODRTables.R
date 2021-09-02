# Write downloaded pids to a file

library(data.table)

files <- list.files(path = "./CODR_tables")

# Check if files is not empty
if(length(files) > 0){
  
  # Convert them to integer and extract the productId
  files <- as.integer(str_sub(files, 1, 8))
}

fwrite(list(files), "downloaded_pids.csv")
