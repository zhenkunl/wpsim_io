
#!/usr/bin/env python3
import numpy as np
from netCDF4 import Dataset

OUTPUT = "geo_em.d01.nc"

# ---------------------------------------------------------
# Grid configuration
# ---------------------------------------------------------
nx = 20
ny = 20

# Regular latitude-longitude grid
ref_lat = 35.0
ref_lon = 110.0
dx = 0.1
dy = 0.1

start_date = "2020-01-01_00:00:00"

# Coordinates of mass points
x = (np.arange(nx) - (nx - 1) / 2.0) * dx
y = (np.arange(ny) - (ny - 1) / 2.0) * dy

lon2d, lat2d = np.meshgrid(ref_lon + x, ref_lat + y)

# Staggered coordinates
lon_u, lat_u = np.meshgrid(
    ref_lon + (np.arange(nx + 1) - nx / 2.0) * dx,
    ref_lat + y
)

lon_v, lat_v = np.meshgrid(
    ref_lon + x,
    ref_lat + (np.arange(ny + 1) - ny / 2.0) * dy
)

# Grid-cell corner coordinates
lon_c, lat_c = np.meshgrid(
    ref_lon + (np.arange(nx + 1) - nx / 2.0) * dx,
    ref_lat + (np.arange(ny + 1) - ny / 2.0) * dy
)

# ---------------------------------------------------------
# Synthetic static fields
# ---------------------------------------------------------
# Land everywhere, except a small water region
landmask = np.ones((ny, nx), dtype=np.float32)
landmask[8:12, 8:12] = 0.0

# Terrain height (m)
hgt = (
    100.0
    + 20.0 * np.sin(np.deg2rad(lat2d * 3.0))
    + 10.0 * np.cos(np.deg2rad(lon2d * 3.0))
).astype(np.float32)

# MODIS 21-category land use
num_land_cat = 21
lu_index = np.ones((ny, nx), dtype=np.float32)
lu_index[landmask == 0] = 17.0

landusef = np.zeros(
    (num_land_cat, ny, nx), dtype=np.float32
)
for j in range(ny):
    for i in range(nx):
        category = int(lu_index[j, i]) - 1
        landusef[category, j, i] = 1.0

# Soil categories
num_soil_cat = 16
soilctop = np.ones((ny, nx), dtype=np.float32)
soilcbot = np.ones((ny, nx), dtype=np.float32)
soilctop[landmask == 0] = 14.0
soilcbot[landmask == 0] = 14.0

# Monthly fields
month = 12
albedo12m = np.full(
    (month, ny, nx), 0.20, dtype=np.float32
)
greenfrac = np.full(
    (month, ny, nx), 0.50, dtype=np.float32
)
lai12m = np.full(
    (month, ny, nx), 2.0, dtype=np.float32
)

# ---------------------------------------------------------
# NetCDF helpers
# ---------------------------------------------------------
def add_var(ds, name, dims, data, units, description):
    var = ds.createVariable(
        name, "f4", dims, zlib=True, complevel=1
    )
    var[:] = data
    var.units = units
    var.description = description
    return var


with Dataset(OUTPUT, "w", format="NETCDF4") as ds:

    # Dimensions
    ds.createDimension("Time", None)
    ds.createDimension("DateStrLen", 19)

    ds.createDimension("west_east", nx)
    ds.createDimension("south_north", ny)

    ds.createDimension("west_east_stag", nx + 1)
    ds.createDimension("south_north_stag", ny + 1)

    ds.createDimension("land_cat", num_land_cat)
    ds.createDimension("soil_cat", num_soil_cat)
    ds.createDimension("month", month)

    # Times
    times = ds.createVariable(
        "Times", "S1", ("Time", "DateStrLen")
    )
    times[0, :] = np.array(
        list(start_date), dtype="S1"
    )

    # Geographic coordinates
    add_var(
        ds, "XLAT_M",
        ("Time", "south_north", "west_east"),
        lat2d[None, :, :],
        "degrees latitude", "Latitude on mass grid"
    )
    add_var(
        ds, "XLONG_M",
        ("Time", "south_north", "west_east"),
        lon2d[None, :, :],
        "degrees longitude", "Longitude on mass grid"
    )

    add_var(
        ds, "XLAT_U",
        ("Time", "south_north", "west_east_stag"),
        lat_u[None, :, :],
        "degrees latitude", "Latitude on U grid"
    )
    add_var(
        ds, "XLONG_U",
        ("Time", "south_north", "west_east_stag"),
        lon_u[None, :, :],
        "degrees longitude", "Longitude on U grid"
    )

    add_var(
        ds, "XLAT_V",
        ("Time", "south_north_stag", "west_east"),
        lat_v[None, :, :],
        "degrees latitude", "Latitude on V grid"
    )
    add_var(
        ds, "XLONG_V",
        ("Time", "south_north_stag", "west_east"),
        lon_v[None, :, :],
        "degrees longitude", "Longitude on V grid"
    )

    add_var(
        ds, "XLAT_C",
        ("Time", "south_north_stag", "west_east_stag"),
        lat_c[None, :, :],
        "degrees latitude", "Latitude at grid cell corners"
    )
    add_var(
        ds, "XLONG_C",
        ("Time", "south_north_stag", "west_east_stag"),
        lon_c[None, :, :],
        "degrees longitude", "Longitude at grid cell corners"
    )

    # Computational coordinates
    for name, data in [
        ("CLAT", lat2d),
        ("CLONG", lon2d),
    ]:
        units = "degrees latitude" if name == "CLAT" else "degrees longitude"
        add_var(
            ds, name,
            ("Time", "south_north", "west_east"),
            data[None, :, :], units, name
        )

    # Map factors and rotation
    mass_shape = (1, ny, nx)
    u_shape = (1, ny, nx + 1)
    v_shape = (1, ny + 1, nx)

    for name in ["MAPFAC_M", "MAPFAC_MX", "MAPFAC_MY"]:
        add_var(
            ds, name,
            ("Time", "south_north", "west_east"),
            np.ones(mass_shape, dtype=np.float32),
            "none", name
        )

    for name in ["MAPFAC_U", "MAPFAC_UX", "MAPFAC_UY"]:
        add_var(
            ds, name,
            ("Time", "south_north", "west_east_stag"),
            np.ones(u_shape, dtype=np.float32),
            "none", name
        )

    for name in ["MAPFAC_V", "MAPFAC_VX", "MAPFAC_VY"]:
        add_var(
            ds, name,
            ("Time", "south_north_stag", "west_east"),
            np.ones(v_shape, dtype=np.float32),
            "none", name
        )

    # Coriolis and rotation angle
    omega = 7.292115e-5
    coriolis = 2.0 * omega * np.sin(np.deg2rad(lat2d))

    add_var(
        ds, "F",
        ("Time", "south_north", "west_east"),
        coriolis[None, :, :],
        "s-1", "Coriolis parameter"
    )
    add_var(
        ds, "E",
        ("Time", "south_north", "west_east"),
        np.zeros(mass_shape, dtype=np.float32),
        "s-1", "Coriolis E parameter"
    )
    add_var(
        ds, "SINALPHA",
        ("Time", "south_north", "west_east"),
        np.zeros(mass_shape, dtype=np.float32),
        "none", "Sine of rotation angle"
    )
    add_var(
        ds, "COSALPHA",
        ("Time", "south_north", "west_east"),
        np.ones(mass_shape, dtype=np.float32),
        "none", "Cosine of rotation angle"
    )

    # Static geographic fields
    add_var(
        ds, "LANDMASK",
        ("Time", "south_north", "west_east"),
        landmask[None, :, :],
        "none", "Landmask : 1=land, 0=water"
    )
    add_var(
        ds, "HGT_M",
        ("Time", "south_north", "west_east"),
        hgt[None, :, :],
        "meters MSL", "Synthetic terrain height"
    )
    add_var(
        ds, "LU_INDEX",
        ("Time", "south_north", "west_east"),
        lu_index[None, :, :],
        "category", "Dominant land use category"
    )
    add_var(
        ds, "LANDUSEF",
        ("Time", "land_cat", "south_north", "west_east"),
        landusef[None, :, :, :],
        "category", "Land use fractional categories"
    )

    add_var(
        ds, "SOILTEMP",
        ("Time", "south_north", "west_east"),
        np.full(mass_shape, 285.0, dtype=np.float32),
        "Kelvin", "Annual mean deep soil temperature"
    )
    add_var(
        ds, "SOILCTOP",
        ("Time", "south_north", "west_east"),
        soilctop[None, :, :],
        "category", "Top-layer soil type"
    )
    add_var(
        ds, "SOILCBOT",
        ("Time", "south_north", "west_east"),
        soilcbot[None, :, :],
        "category", "Bottom-layer soil type"
    )

    add_var(
        ds, "ALBEDO12M",
        ("Time", "month", "south_north", "west_east"),
        albedo12m[None, :, :, :],
        "fraction", "Monthly albedo"
    )
    add_var(
        ds, "GREENFRAC",
        ("Time", "month", "south_north", "west_east"),
        greenfrac[None, :, :, :],
        "fraction", "Monthly green vegetation fraction"
    )
    add_var(
        ds, "LAI12M",
        ("Time", "month", "south_north", "west_east"),
        lai12m[None, :, :, :],
        "m2 m-2", "Monthly leaf area index"
    )

    add_var(
        ds, "SNOALB",
        ("Time", "south_north", "west_east"),
        np.full(mass_shape, 0.50, dtype=np.float32),
        "fraction", "Maximum snow albedo"
    )
    add_var(
        ds, "SLOPECAT",
        ("Time", "south_north", "west_east"),
        np.ones(mass_shape, dtype=np.float32),
        "category", "Slope category"
    )

    # -----------------------------------------------------
    # Global attributes
    # MAP_PROJ=6 means regular latitude-longitude.
    # -----------------------------------------------------
    attrs = {
        "TITLE": "Synthetic geo_em file for wpsim_io testing",
        "START_DATE": start_date,
        "SIMULATION_START_DATE": start_date,

        "WEST-EAST_GRID_DIMENSION": nx + 1,
        "SOUTH-NORTH_GRID_DIMENSION": ny + 1,
        "BOTTOM-TOP_GRID_DIMENSION": 1,

        "WEST-EAST_PATCH_START_UNSTAG": 1,
        "WEST-EAST_PATCH_END_UNSTAG": nx,
        "WEST-EAST_PATCH_START_STAG": 1,
        "WEST-EAST_PATCH_END_STAG": nx + 1,

        "SOUTH-NORTH_PATCH_START_UNSTAG": 1,
        "SOUTH-NORTH_PATCH_END_UNSTAG": ny,
        "SOUTH-NORTH_PATCH_START_STAG": 1,
        "SOUTH-NORTH_PATCH_END_STAG": ny + 1,

        "GRIDTYPE": "C",
        "DX": dx,
        "DY": dy,

        "CEN_LAT": ref_lat,
        "CEN_LON": ref_lon,
        "MOAD_CEN_LAT": ref_lat,

        "TRUELAT1": ref_lat,
        "TRUELAT2": ref_lat,
        "STAND_LON": ref_lon,

        "POLE_LAT": 90.0,
        "POLE_LON": 0.0,

        "MAP_PROJ": 6,
        "MMINLU": "MODIFIED_IGBP_MODIS_NOAH",
        "NUM_LAND_CAT": num_land_cat,

        "ISWATER": 17,
        "ISLAKE": 21,
        "ISICE": 15,
        "ISURBAN": 13,
        "ISOILWATER": 14,

        "grid_id": 1,
        "parent_id": 1,
        "i_parent_start": 1,
        "j_parent_start": 1,
        "parent_grid_ratio": 1,

        "i_parent_end": nx,
        "j_parent_end": ny,
    }

    for key, value in attrs.items():
        ds.setncattr(key, value)

    # Four corner locations, repeated for the mass/U/V grids.
    corners_lat = [
        float(lat_c[0, 0]), float(lat_c[0, -1]),
        float(lat_c[-1, -1]), float(lat_c[-1, 0])
    ]
    corners_lon = [
        float(lon_c[0, 0]), float(lon_c[0, -1]),
        float(lon_c[-1, -1]), float(lon_c[-1, 0])
    ]

    ds.setncattr("corner_lats", np.array(corners_lat * 4, dtype=np.float32))
    ds.setncattr("corner_lons", np.array(corners_lon * 4, dtype=np.float32))

print(f"Created {OUTPUT}")
print(f"Grid size: {nx} x {ny}")
