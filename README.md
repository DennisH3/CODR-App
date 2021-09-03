[(Français)](#le-nom-du-projet)

# CODR Search Engine Shiny App

**Note**: CODR tables is the new name that replaced CANSIM tables

The CODR Search Engine Shiny App aims to improve searching for data compared to using the Statistics Canada website ([https://www150.statcan.gc.ca/n1/en/type/data](https://www150.statcan.gc.ca/n1/en/type/data))

## Data
- CODR_tables.zip: contains individual metadata files
- downloaded_pids.csv: contains a list of product IDs that have already been downloaded

**IMPORTANT** - Please use the included data rather than downloading everything to avoid putting strain on the WDS API.

Moreover, the estimated time to download all the metadata files from nothing is 18 hours.

I have already downloaded all of the metadata files as of September 2nd, 2021 for a total 5987 parquet files.
Parquet files were used to save the data as they are memory efficient. Converting from CSV to parquet was a reduction from 27.84 GB to 217 MB.

For more information about parquet files, visit: [https://parquet.apache.org/](https://parquet.apache.org/)

## Files
- codrApp.R: the RShiny CODR search engine app. Sources getMetaData.R to automatically update to have all published CODR tables.
- compileMetaData.R: a script that compiles all the parquet files into a zipped csv file (csv.gz). As of September 2nd, 2021, the output csv.gz file is 1 GB. Unzipping it results in a ~28GB file. The output of this script is not included in this repository.
- csvToParquet.R: converts the metadata csv files to parquet. There are no csv files remaining to convert.
- downloadedCODRTables.R: generates the downloaded_pids.csv by reading the list of files in the directory `/CODR_tables`
- getMetaData.R: downloads the individual metadata parquet files for all CODR table product IDs that have not already been downloaded

## Dependencies

### Data collection
- httr
- curl
- cansim
- CANSIM2R

### Data processing
- arrow
- jsonlite
- tidyverse
- data.table

### Data visualization
- plotly
- htmlwidgets
- Hmisc

### App development
library(shiny)
library(shinyjs)

## Using the App

The app takes ~3.5 minutes to launch.

### First Tab
Searches for CODR tables by keyword, renders a specific CODR data table, and then creates a scatter plot.

### Second Tab
Searches CODR tables using metadata and enables the user to download the filtered resulting data frame as a csv file.

Note: you **MUST** click on the Reset button per new query.

R and Python tutorials on how to use the WDS API, including how to download multiple CODR tables, can be at:
- [R CODR tutorial](https://github.com/DennisH3/R-notebooks/blob/master/R-Markdown/R-Notebook-Example-CODR-API.Rmd) 
- [Python CODR tutorial](https://github.com/DennisH3/jupyter-notebooks/blob/master/python/01-Python-Notebook-Example-CODR-API.ipynb)

### How to Contribute

See [CONTRIBUTING.md](CONTRIBUTING.md)

### License

Unless otherwise noted, the source code of this project is covered under Crown Copyright, Government of Canada, and is distributed under the [MIT License](LICENSE).

The Canada wordmark and related graphics associated with this distribution are protected under trademark law and copyright law. No permission is granted to use them outside the parameters of the Government of Canada's corporate identity program. For more information, see [Federal identity requirements](https://www.canada.ca/en/treasury-board-secretariat/topics/government-communications/federal-identity-requirements.html).
______________________

### Comment contribuer

Voir [CONTRIBUTING.md](CONTRIBUTING.md)

### Licence

Sauf indication contraire, le code source de ce projet est protégé par le droit d'auteur de la Couronne du gouvernement du Canada et distribué sous la [licence MIT](LICENSE).

Le mot-symbole « Canada » et les éléments graphiques connexes liés à cette distribution sont protégés en vertu des lois portant sur les marques de commerce et le droit d'auteur. Aucune autorisation n'est accordée pour leur utilisation à l'extérieur des paramètres du programme de coordination de l'image de marque du gouvernement du Canada. Pour obtenir davantage de renseignements à ce sujet, veuillez consulter les [Exigences pour l'image de marque](https://www.canada.ca/fr/secretariat-conseil-tresor/sujets/communications-gouvernementales/exigences-image-marque.html).
