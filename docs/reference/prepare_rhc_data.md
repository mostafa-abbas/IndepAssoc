# Prepare the RHC dataset for analysis

Reads a raw RHC (Right Heart Catheterization) CSV and returns a cleaned
data frame plus the 50-column covariate vector. The raw file carries a
`write.csv` row-names column named `""`, stores the `cat2` category
"None" as the literal text `"NA"`, stores every other missing value as
the literal text `"NA"`, and codes the `swang1` exposure and the
`death`/`dth30` outcomes as text. These quirks are resolved here so
downstream analysis receives a typed, numeric-encoded data frame.

## Usage

``` r
prepare_rhc_data(path)
```

## Arguments

- path:

  Character; path to the RHC CSV file.

## Value

A list with two elements: `data`, the cleaned data frame, and
`covariates`, a character vector of the 50 covariate column names.

## Examples

``` r
tmp <- tempfile(fileext = ".csv")
write.csv(data.frame(ptid = "p1", cat2 = "None", swang1 = "RHC",
                     dth30 = "Yes", death = "Yes",
                     sadmdte = "11142", dschdte = "11151"),
          tmp)
prepare_rhc_data(tmp)
#> $data
#>   ptid cat2 swang1 dth30 death sadmdte dschdte los
#> 1   p1 None      1     1     1   11142   11151   9
#> 
#> $covariates
#> [1] "cat2"
#> 
```
