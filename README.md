# wpsim_io (WPS Intermediate File IO library)

**wpsim_io** is a Fortran library for reading and writing WRF/WPS Intermediate Format files (version 5). It provides an object-oriented API for representing map projections, meteorological fields, and intermediate-file records.

The library can be used to prepare meteorological input files for the WRF Preprocessing System (WPS), including files that are subsequently processed by `metgrid.exe`.

> **Important:** A file that is syntactically valid and readable by `metgrid.exe` is not necessarily sufficient to initialize a WRF simulation. The meteorological fields required by `real.exe` must also be present. See [Required meteorological input for WRF](#required-meteorological-input-for-wrf) below.

## Features

- Reads and writes **WPS Intermediate Format version 5**.
- Supports the following map projections:
  - Cylindrical equidistant (latitude/longitude)
  - Mercator
  - Lambert conformal
  - Gaussian
  - Polar stereographic
- Provides derived Fortran types for:
  - Two-dimensional fields
  - Three-dimensional fields with configurable vertical levels
  - Three-dimensional soil fields with layer-specific field names
- Supports files containing multiple field records.
- Provides an object-oriented API based on Fortran derived types and type-bound procedures.
- Handles the format's big-endian representation through compiler-specific options configured by CMake.
- Provides CMake build, install, and package-export support.

## Requirements

- CMake 3.20 or later
- A supported Fortran compiler:
  - GNU Fortran (gfortran)
  - NVIDIA HPC SDK Fortran (nvfortran)
  - Intel Fortran (ifort or ifx)

The project configures compiler options for byte swapping and other format/build requirements in `cmake/compilers.cmake`.

## Build

Configure and build the library:

```bash
cmake -S . -B build
cmake --build build
```

To build with runtime checks and debugging information:

```bash
cmake -S . -B build-debug -DCMAKE_BUILD_TYPE=Debug
cmake --build build-debug
```

The examples are enabled by the `BUILD_TESTING` CMake option, which is enabled by default through CTest. To disable them:

```bash
cmake -S . -B build -DBUILD_TESTING=OFF
```

## Install

Install the library to a chosen prefix:

```bash
cmake --install build --prefix /path/to/install
```

The installation includes the library, the Fortran module file, and CMake package configuration files.

A CMake project can then locate and link the installed package:

```cmake
find_package(wpsim_io CONFIG REQUIRED)

target_link_libraries(my_application
    PRIVATE wpsim_io::wpsim_io
)
```

Make sure the installation prefix is in CMake's package search path if it is not a standard system prefix. For example:

```bash
cmake -S . -B build -DCMAKE_PREFIX_PATH=/path/to/install
```

In Fortran source files, import the library's public umbrella module:

```fortran
use wpsim_io
```

## Usage

### Read an intermediate file

The `wpsim_file` type provides methods to open a file, read its records, print record summaries, and close the file.

```fortran
program read_wpsim_example
    use wpsim_io
    implicit none

    type(wpsim_file) :: im_file

    call im_file%open(file="data/FILE:2013-08-11_00")
    call im_file%read()
    call im_file%print()
    call im_file%close()

end program read_wpsim_example
```

The `file` argument is the path to an existing WPS Intermediate Format file. The `read()` method reads the records in the file, and `print()` writes their metadata and a sample data value to standard output.

### Write a two-dimensional field

A `wpsim_proj` object describes the grid projection. A `wpsim_field2d` object contains a two-dimensional data array and its field metadata.

```fortran
program write_2d_field
    use wpsim_io
    implicit none

    integer, parameter  :: nx = 100, ny = 80
    real                :: data(nx, ny)
    type(wpsim_proj)    :: proj
    type(wpsim_field2d) :: field
    type(wpsim_file)    :: im_file
    character(len=24)   :: date

    date = "2026-11-03_18"
    data = 280.0

    proj = wpsim_proj( &
        iproj=0, &
        startlat=90.0, &
        startlon=0.0, &
        deltalat=-1.0, &
        deltalon=1.0 &
    )

    field = wpsim_field2d("TT", date, data)

    call im_file%create(dir="./", date=date)
    call im_file%write(proj, field)
    call im_file%close()

end program write_2d_field
```

By default, `create()` uses the filename prefix `FILE:`. The example therefore creates a file named `FILE:2026-11-03_18` in the current directory. A different prefix can be supplied with the optional `prefix` argument. Alternatively, pass a complete output path using the `file` argument.

### Write three-dimensional fields

The library accepts three-dimensional arrays through `wpsim_field3d`. Each vertical level is written as an individual two-dimensional record. Optional `levels` values specify the level metadata associated with each slice.

```fortran
real :: data3d(nx, ny, nz)
real :: levels(nz)

levels = [1000.0, 925.0, 850.0, 700.0]
field3d = wpsim_field3d("TT", date, data3d, levels)
call im_file%write(proj, field3d)
```

If `levels` is omitted, the constructor assigns level values 1 through `nz`. For pressure-level input, provide the actual pressure values and the corresponding data slices. The field name, units, level metadata, and vertical coordinate convention must agree with the source dataset and the WPS/WRF expectations.

### Write soil-layer fields

Use `wpsim_field3d_soil` for fields whose third dimension represents soil layers. The supplied layer identifiers are appended to the base field name to form the individual record names.

```fortran
character(len=6) :: layers(4)
real             :: soil_data(nx, ny, 4)

layers = ["000010", "010040", "040100", "100200"]
field_soil = wpsim_field3d_soil("ST", date, soil_data, layers)
call im_file%write(proj, field_soil)
```

For example, the base field name `ST` and layer identifier `000010` produce the record field name `ST000010`. For the WRF soil-layer convention, the six digits encode the layer-top and layer-bottom depths in centimeters: `tttbbb`.

## Required meteorological input for WRF

The official [WRF Users Guide: Required Input for Running WRF](https://www2.mmm.ucar.edu/wrf/users/wrf_users_guide/build/html/wps.html#required-input-for-running-wrf) specifies the minimum meteorological and land-surface fields that must be available in the output of `metgrid.exe` for `real.exe` to initialize a simulation.

When generating WPS Intermediate files with this library, make sure the input records collectively provide the required fields below. These are requirements for the meteorological input dataset as a whole; they do not imply that every field must be stored in one file or that every field must be supplied by the same data source.

### Three-dimensional atmospheric fields

| Intermediate field name | Units | Description | Requirement / alternative |
|---|---|---|---|
| `TT` | K | 3-D air temperature | Required |
| `RH` | % | 3-D relative humidity | Required unless 3-D `SPECHUMD` is provided |
| `SPECHUMD` | kg kg-1 | 3-D specific humidity | Required unless 3-D `RH` is provided |
| `UU` | m s-1 | 3-D U-component of wind | Required |
| `VV` | m s-1 | 3-D V-component of wind | Required |
| `GHT` | m | 3-D geopotential height | Required |
| `PRESSURE` | Pa | 3-D pressure | Required for non-isobaric datasets |

For isobaric datasets, pressure is represented by the pressure-level metadata associated with each field record; the additional 3-D `PRESSURE` field is only required by the guide for non-isobaric datasets.

### Surface and near-surface fields

| Intermediate field name | Units | Description | Requirement / alternative |
|---|---|---|---|
| `PSFC` | Pa | Surface pressure | Required |
| `PMSL` | Pa | Mean sea-level pressure | Required |
| `SKINTEMP` | K | Skin temperature | Required |
| `SOILHGT` | m | Soil height | Required |
| `TT` | K | 2-m air temperature | Required |
| `RH` | % | 2-m relative humidity | Required unless 2-m `SPECHUMD` is provided |
| `SPECHUMD` | kg kg-1 | 2-m specific humidity | Required unless 2-m `RH` is provided |
| `UU` | m s-1 | 10-m U-component of wind | Required |
| `VV` | m s-1 | 10-m V-component of wind | Required |
| `LANDSEA` | fraction | Land-sea mask (0=water, 1=land) | Required |

Note that the same intermediate field names can be used for different vertical or surface levels. For example, `TT` is used for both 3-D air temperature and 2-m air temperature. The level metadata (`xlvl`) distinguishes the surface/near-surface record from atmospheric levels.

### Soil fields

The guide lists two alternative naming conventions for soil moisture and soil temperature:

| Intermediate field name pattern | Units | Description | Requirement / alternative |
|---|---|---|---|
| `SMtttbbb` | m3 m-3 | Soil moisture for a layer | Preferred layer-based form |
| `STtttbbb` | K | Soil temperature for a layer | Preferred layer-based form |
| `SOILMmmm` | kg m-3 | Soil moisture at a depth | Alternative to `SMtttbbb` |
| `SOILTmmm` | K | Soil temperature at a depth | Alternative to `STtttbbb` |

In `SMtttbbb` and `STtttbbb`, `ttt` is the top depth and `bbb` is the bottom depth of the soil layer, both in centimeters. In `SOILMmmm` and `SOILTmmm`, `mmm` is the soil depth in centimeters. The depth/layer convention and the fields supplied must be consistent with the land-surface scheme and the WRF configuration.

### Practical checklist

Before running `metgrid.exe` and then `real.exe`, check that:

1. Every required atmospheric and surface field listed above is available for the required valid times.
2. At each required atmospheric level, the 3-D temperature, humidity (RH or SPECHUMD), U wind, V wind, and geopotential height records are present.
3. For non-isobaric input, the 3-D pressure field is also present.
4. Surface pressure, mean sea-level pressure, skin temperature, soil height, 2-m temperature, 2-m humidity (RH or SPECHUMD), 10-m winds, and land-sea mask are available.
5. Soil moisture and soil temperature are supplied using a supported layer/depth convention appropriate for the selected land-surface scheme.
6. All fields have consistent valid times, horizontal dimensions, grid location, projection metadata, and compatible units.
7. The input prefixes and valid times match the `fg_name`, `constants_name`, `start_date`, `end_date`, and `interval_seconds` settings in `namelist.wps`.

The fields listed here are the WRF Users Guide's minimum meteorological input set, not a universal recipe for every WRF configuration. Additional fields may be needed depending on the selected physics options, land-surface scheme, data source, and `METGRID.TBL`. Static geographical fields (for example, terrain, land use, soil category, and map information) are normally supplied by `geogrid.exe` through the `geo_em.d0*` files, rather than being recreated as ordinary time-varying meteorological records.

### Important implementation note: field names and metadata

The WRF Users Guide names the 3-D geopotential-height field `GHT`. The current library's built-in 3-D field metadata defaults recognize `HGT`; therefore, when writing the WPS-required `GHT` field, pass `HGT` instead. For example:

```fortran
field3d = wpsim_field3d( &
    "GHT", date, height_data, pressure_levels
)
call im_file%write(proj, field3d)
```

For field names not covered by the library's built-in metadata defaults, pass `units` and `desc` arguments explicitly to provide the required metadata. For example, to write a surface field named `GEOPT`, use:

```fortran
field3d = wpsim_field3d( &
    "GEOPT", date, geopt_data, pressure_levels, &
    units="m2 s-2", &
    desc="Geopotential" &
)
call im_file%write(proj, field3d)
```

Similarly, Surface and near-surface fields or soil fields should be created with explicit metadata as supported by the relevant field constructor. Always check the actual intermediate record names and metadata against the WRF Users Guide and the `METGRID.TBL` used by your WPS installation.

## Map projections

The projection type is constructed with `wpsim_proj`. The `iproj` values currently supported by the library are:

| `iproj` | Projection | Main projection parameters |
|---:|---|---|
| 0 | Latitude/longitude | `startlat`, `startlon`, `deltalat`, `deltalon` |
| 1 | Mercator | `startlat`, `startlon`, `dx`, `dy`, `truelat1` |
| 3 | Lambert conformal | `startlat`, `startlon`, `dx`, `dy`, `xlonc`, `truelat1`, `truelat2` |
| 4 | Gaussian | `startlat`, `startlon`, `nlats`, `deltalon` |
| 5 | Polar stereographic | `startlat`, `startlon`, `xlonc`, `truelat1` |

Optional projection arguments include `earth_rad`, `is_wind_grid_rel`, and `startloc`. The default Earth radius is 6371.229 km, wind-grid-relative is false, and the start location is `SWCORNER`.

## API overview

The public umbrella module is `wpsim_io`.

| Type | Purpose | Main procedures / constructors |
|---|---|---|
| `wpsim_file` | File lifecycle and record I/O | `create()`, `open()`, `read()`, `write()`, `print()`, `close()` |
| `wpsim_proj` | Grid projection metadata | `wpsim_proj(...)` |
| `wpsim_field2d` | A two-dimensional field | `wpsim_field2d(...)` |
| `wpsim_field3d` | A field with multiple vertical levels | `wpsim_field3d(...)`, `tofields()` |
| `wpsim_field3d_soil` | A field with multiple soil layers | `wpsim_field3d_soil(...)`, `tofields()` |

A file can be opened for reading by supplying either a complete `file` path or a `dir`, `date`, and optional `prefix`. For writing, use `create()` with the same argument conventions. The default prefix is `FILE:`.

The field constructors accept optional metadata such as `units`, `map_source`, and `desc`. When omitted, the library supplies defaults for the field names currently recognized by the constructors. Supply all relevant metadata explicitly when working with other field definitions.

## Examples and tests

The `examples/` directory contains:

- `read_wpsim_example.F90`: reads and prints records from the sample file in `data/`.
- `write_wpsim_example.F90`: writes 2-D, 3-D, and soil-layer fields to an intermediate file.

Build and run the examples with CTest:

```bash
ctest --test-dir build --output-on-failure
```

You can also run the executables directly from the build directory:

```bash
./build/examples/read_wpsim_example
./build/examples/write_wpsim_example
```

## Project layout

```text
wpsim_io/
├── cmake/       # Compiler settings and CMake package configuration
├── data/        # Sample WPS Intermediate Format file
├── examples/    # Read and write examples
└── src/         # Fortran library source
    ├── wpsim_constants.F90
    ├── wpsim_projection.F90
    ├── wpsim_fields.F90
    ├── wpsim_files.F90
    └── wpsim_io.F90
```

## Format and compatibility notes

- The implementation currently supports Intermediate Format version 5.
- The file is handled using Fortran unformatted I/O. CMake applies compiler-specific byte-order options for the supported compiler families.
- Files should be read and written with compatible compiler/runtime settings so that the binary representation matches the WPS format.
- A successful library write does not by itself validate that the resulting dataset contains every field required by `metgrid.exe` and `real.exe`.

## License

This project is licensed under the [MIT License](LICENSE).

## References

- [WRF Users Guide — The WRF Preprocessing System (WPS)](https://www2.mmm.ucar.edu/wrf/users/wrf_users_guide/build/html/wps.html)
- [WRF Users Guide — Required Input for Running WRF](https://www2.mmm.ucar.edu/wrf/users/wrf_users_guide/build/html/wps.html#required-input-for-running-wrf)
