# Split generators data

`split_generators_data.jl` is a simple script to refactor a folder case for GenX v0.3.6 to GenX v0.4.0, and to split the `Generators_data.csv` file into the new resource `csv` files.

## How to use it
- Copy the full path to the case folder you want to refactor and paste it into the `PATH_IN` variable at the top of the script:

```julia
PATH_IN = "/Users/username/.../case_folder"
```
- (Optional) Change the `PATH_OUT` variable to the desired output folder (by default the script will create a new `case_restr` folder in the same folder as the script)

```julia
PATH_OUT = "/Users/username/.../case_restr"
```
- Run the script

```
$ julia

pkg> add CSV, DataFrames
julia> include("split_generators_data.jl")
```

or, alternatively:
```
$ julia --project=.

pkg> instantiate
julia> include("split_generators_data.jl")
```

## Multistage
In the case of multistage input data, please split each `Inputs_p*` folder separately.

## Add more resources-specific columns
At the top of the script, there are some vectors that contain the columns that are specific to each resource (e.g., `thermal_cols`, `hydro_cols`, `stor_cols`, etc). If you need to add more columns that are specific to a resource, you can add them to the corresponding vector (the column names are case-sensitive). 

## Output
The script will create a new folder (default `case_restr`) with the refactored case and the new `csv` files.

## Troubleshooting
This script is considered experimental and may not work for all cases. If you encounter any issues, please contact Luca Bonaldo.
