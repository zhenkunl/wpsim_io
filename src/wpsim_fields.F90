module wpsim_fields
  use wpsim_constants
  use wpsim_projection

  implicit none
  ! private ! NOTE: an issue "Unable to resolve user defined io" arise when using write(*, *) in other modules
  public :: wpsim_field
  public :: wpsim_field2d
  public :: wpsim_field3d
  public :: wpsim_field3d_soil
  public :: wpsim_record
  public :: wpsim_record_link

  type, abstract :: wpsim_field
    private
    integer                        :: version
    integer                        :: nx
    integer                        :: ny
    real                           :: xfcst
    character(len=9)               :: field
    character(len=24)              :: hdate
    character(len=25)              :: units
    character(len=32)              :: map_source
    character(len=46)              :: desc
  end type wpsim_field

  type, extends(wpsim_field) :: wpsim_field2d
    private
    real                           :: xlvl
    real, allocatable              :: slab(:, :)
  end type wpsim_field2d

  type, extends(wpsim_field) :: wpsim_field3d
    private
    integer                        :: nz
    real, allocatable              :: levels(:)
    real, allocatable              :: slab(:, :, :)
  contains
    procedure, public, pass(self)  :: tofields => field3d_to_field2d
  end type wpsim_field3d

  type, extends(wpsim_field) :: wpsim_field3d_soil
    private
    real                           :: xlvl
    integer                        :: nz
    character(len=9), allocatable  :: name(:)
    real, allocatable              :: slab(:, :, :)
  contains
    procedure, public, pass(self)  :: tofields => field3d_soil_to_field2d
  end type wpsim_field3d_soil

  type :: wpsim_record
    private
    type(wpsim_proj)               :: proj
    type(wpsim_field2d)            :: field
  contains
    procedure, public, pass(self)  :: init  => init_record
    procedure, public, pass(self)  :: read  => read_record
    procedure, public, pass(self)  :: write => write_record
    generic, public                :: write(formatted) => write_formatted
    procedure, private, pass(self) :: write_formatted
  end type wpsim_record

  type wpsim_record_link
    type(wpsim_record)               :: record
    type(wpsim_record_link), pointer :: next
  end type wpsim_record_link

  interface wpsim_field2d
    module procedure wpsim_field2d_constructor
  end interface wpsim_field2d

  interface wpsim_field3d
    module procedure wpsim_field3d_constructor
  end interface wpsim_field3d

  interface wpsim_field3d_soil
    module procedure wpsim_field3d_soil_constructor
  end interface wpsim_field3d_soil

contains

  function wpsim_field2d_constructor(field, hdate, slab, xlvl, units, map_source, desc) result(self)

    implicit none
    character(len=*), intent(in)           :: field
    character(len=*), intent(in)           :: hdate
    real, intent(in)                       :: slab(:, :)
    real, intent(in), optional             :: xlvl
    character(len=*), intent(in), optional :: units
    character(len=*), intent(in), optional :: map_source
    character(len=*), intent(in), optional :: desc

    integer                                :: nx
    integer                                :: ny
    type(wpsim_field2d)                    :: self

    nx = size(slab, 1)
    ny = size(slab, 2)
    allocate(self%slab(nx, ny))
    self%slab = slab

    self%version = VERSION
    self%nx      = nx
    self%ny      = ny
    self%xfcst   = 0.0
    self%field   = field
    self%hdate   = hdate

    if (present(map_source)) then
      self%map_source = map_source
    else
      self%map_source = "WPSIM_IO"
    end if

    if (present(xlvl) .and. present(units) .and. present(desc)) then
      self%xlvl = xlvl
      self%units = units
      self%desc  = desc
    else
      if (trim(field) == "PSFC") then
        self%units = "Pa"
        self%desc  = "Surface pressure"
        self%xlvl  = 200100
      else if (trim(field) == "PMSL") then
        self%units = "Pa"
        self%desc  = "Mean sea-level pressure"
        self%xlvl  = 201300
      else if (trim(field) == "SKINTEMP") then
        self%units = "K"
        self%desc  = "Skin temperature"
        self%xlvl  = 200100
      else if (trim(field) == "SOILHGT") then
        self%units = "m"
        self%desc  = "Soil height"
        self%xlvl  = 200100
      else if (trim(field) == "TT") then
        self%units = "K"
        self%desc  = "2-meter air temperature"
        self%xlvl  = 200100
      else if (trim(field) == "RH") then
        self%units = "%"
        self%desc  = "2-meter relative humidity"
        self%xlvl  = 200100
      else if (trim(field) == "SPECHUMD") then
        self%units = "kg kg-1"
        self%desc  = "2-meter specific humidity"
        self%xlvl  = 200100
      else if (trim(field) == "UU") then
        self%units = "m s-1"
        self%desc  = "10-meter wind u-component"
        self%xlvl  = 200100
      else if (trim(field) == "VV") then
        self%units = "m s-1"
        self%desc  = "10-meter wind v-component"
        self%xlvl  = 200100
      else if (trim(field) == "LANDSEA") then
        self%units = "fraction"
        self%desc  = "Land sea mask"
        self%xlvl  = 200100
      else if (trim(field) == "SST") then
        self%units = "K"
        self%desc  = "Sea surface temperature"
        self%xlvl  = 201300
      else if (trim(field) == "SEAICE") then
        self%units = "fraction"
        self%desc  = "Sea-ice-fraction"
        self%xlvl  = 200100
      else if (trim(field) == "SNOW") then
        self%units = "kg m-2"
        self%desc  = "Water equivalent of Accum snow depth"
        self%xlvl  = 200100
      else if (trim(field) == "SNOWH") then
        self%units = "kg m-2"
        self%desc  = "Physical Snow Depth"
        self%xlvl  = 200100
      else if (trim(field) == "TAVGSFC") then
        self%units = "K"
        self%desc  = "Daily mean of surface air temperature"
        self%xlvl  = 200100
      else
        error stop 'ERROR: unsupported 2-d field: '//trim(field)//'!'
      end if
    end if

  end function wpsim_field2d_constructor

  function wpsim_field3d_constructor(field, hdate, slab, levels, units, map_source, desc) result(self)

    implicit none
    character(len=*), intent(in)           :: field
    character(len=*), intent(in)           :: hdate
    real, intent(in)                       :: slab(:, :, :)
    real, intent(in), optional             :: levels(:)
    character(len=*), intent(in), optional :: units
    character(len=*), intent(in), optional :: map_source
    character(len=*), intent(in), optional :: desc

    integer                                :: nx
    integer                                :: ny
    integer                                :: nz
    type(wpsim_field3d)                    :: self
    integer                                :: i

    nx = size(slab, 1)
    ny = size(slab, 2)
    nz = size(slab, 3)
    allocate(self%slab(nx, ny, nz))
    self%slab = slab

    self%version = VERSION
    self%nx      = nx
    self%ny      = ny
    self%nz      = nz
    self%xfcst   = 0.0
    self%field   = field
    self%hdate   = hdate

    if (present(map_source)) then
      self%map_source = map_source
    else
      self%map_source = "WPSIM_IO"
    end if

    if (present(levels)) then
      self%levels = levels
    else
      allocate(self%levels(nz))
      do i = 1, nz
        self%levels(i) = real(i)
      end do
    end if

    if (present(units) .and. present(desc)) then
      self%units  = units
      self%desc   = desc
    else
      if (trim(field) == "TT") then
        self%units = "K"
        self%desc  = "3-d air temperature"
      else if (trim(field) == "RH") then
        self%units = "%"
        self%desc  = "3-d relative humidity"
      else if (trim(field) == "SPECHUMD") then
        self%units = "kg kg-1"
        self%desc  = "3-d specific humidity"
      else if (trim(field) == "UU") then
        self%units = "m s-1"
        self%desc  = "3-d wind u-component"
      else if (trim(field) == "VV") then
        self%units = "m s-1"
        self%desc  = "3-d wind v-component"
      else if (trim(field) == "HGT") then
        self%units = "m"
        self%desc  = "3-d geopotential height"
      else if (trim(field) == "PRESSURE") then
        self%units = "Pa"
        self%desc  = "3-d pressure"
      else
        error stop 'ERROR: unsupported 3-d field: '//trim(field)//'!'
      end if
    end if

  end function wpsim_field3d_constructor

  function wpsim_field3d_soil_constructor(field, hdate, slab, layers, units, map_source, desc) result(self)

    implicit none
    character(len=*), intent(in)           :: field
    character(len=*), intent(in)           :: hdate
    real, intent(in)                       :: slab(:, :, :)
    character(len=*), intent(in)           :: layers(:)
    character(len=*), intent(in), optional :: units
    character(len=*), intent(in), optional :: map_source
    character(len=*), intent(in), optional :: desc

    integer                                :: nx
    integer                                :: ny
    integer                                :: nz
    type(wpsim_field3d_soil)               :: self
    integer                                :: i

    nx = size(slab, 1)
    ny = size(slab, 2)
    nz = size(slab, 3)
    allocate(self%slab(nx, ny, nz))
    allocate(self%name(nz))
    self%slab = slab

    self%version = VERSION
    self%nx      = nx
    self%ny      = ny
    self%nz      = nz
    self%xfcst   = 0.0
    self%field   = field
    self%hdate   = hdate

    do i = 1, nz
      self%name(i) = trim(self%field)//trim(layers(i))
    end do

    if (present(map_source)) then
      self%map_source = map_source
    else
      self%map_source = "WPSIM_IO"
    end if

    self%xlvl = 200100

    if (present(units) .and. present(desc)) then
      self%units  = units
      self%desc   = desc
    else
      if (trim(field) == "SM") then
        self%units = "m3 m-3"
        self%desc  = "Soil moisture "
      else if (trim(field) == "ST") then
        self%units = "K"
        self%desc  = "Soil temperature "
      else if (trim(field) == "SOILM") then
        self%units = "kg m-3"
        self%desc  = "Soil moisture "
      else if (trim(field) == "SOILT") then
        self%units = "K"
        self%desc  = "Soil temperature "
      else
        error stop 'ERROR: unsupported soild field: '//trim(field)//'!'
      end if
    end if

  end function wpsim_field3d_soil_constructor

  function field3d_to_field2d(self) result(res)

    implicit none
    class(wpsim_field3d), intent(in)   :: self

    type(wpsim_field2d), allocatable   :: res(:)
    integer                            :: nz
    integer                            :: i

    nz = self%nz
    allocate(res(nz))

    do i = 1, nz
      res(i) = wpsim_field2d(self%field, self%hdate, self%slab(:, :, i), self%levels(i), self%units, self%map_source, self%desc)
    end do

  end function field3d_to_field2d

  function field3d_soil_to_field2d(self) result(res)

    implicit none
    class(wpsim_field3d_soil), intent(in) :: self

    type(wpsim_field2d), allocatable      :: res(:)
    integer                               :: nz
    integer                               :: i

    nz = self%nz
    allocate(res(nz))

    do i = 1, nz
      res(i) = wpsim_field2d(self%name(i), self%hdate, self%slab(:, :, i), self%xlvl, self%units, self%map_source, self%desc)
    end do

  end function field3d_soil_to_field2d

  subroutine init_record(self, proj, field)

    implicit none
    class(wpsim_record), intent(inout) :: self
    type(wpsim_proj), intent(in)       :: proj
    type(wpsim_field2d), intent(in)    :: field

    self%proj  = proj
    self%field = field

  end subroutine init_record

  subroutine read_record(self, iunit, iostat)

    implicit none
    class(wpsim_record), intent(inout) :: self
    integer, intent(in)                :: iunit
    integer, intent(out)               :: iostat

    type(wpsim_proj)                   :: proj
    type(wpsim_field2d)                :: field

    read(unit=iunit, iostat=iostat) field%version
    if (iostat /= 0) then
      return
    end if

    if (field%version /= VERSION) then
      error stop 'ERROR: unsupported WPS intermediate format version !'
    end if

    read(iunit, iostat=iostat) field%hdate, field%xfcst, field%map_source, field%field, &
                               field%units, field%desc, field%xlvl, field%nx, field%ny, &
                               proj%iproj
    if (iostat /= 0) then
      error stop 'ERROR: can not read metadata from WPS intermediate format file!'
    end if

    if (proj%iproj == IPROJ_LATLON) then ! Cylindrical equidistant (lat/lon)
      read(iunit, iostat=iostat) proj%startloc, proj%startlat, proj%startlon,           &
                                 proj%deltalat, proj%deltalon, proj%earth_radius
    else if (proj%iproj == IPROJ_MERCATOR) then ! Mercator
      read(iunit, iostat=iostat) proj%startloc, proj%startlat, proj%startlon,           &
                                 proj%dx, proj%dy, proj%truelat1, proj%earth_radius
    else if (proj%iproj == IPROJ_LAMBERT_CONFORMAL) then ! Lambert conformal
      read(iunit, iostat=iostat) proj%startloc, proj%startlat, proj%startlon,           &
                                 proj%dx, proj%dy, proj%xlonc, proj%truelat1,           &
                                 proj%truelat2, proj%earth_radius
    else if (proj%iproj == IPROJ_GAUSSIAN) then ! Gaussian
      read(iunit, iostat=iostat) proj%startloc, proj%startlat, proj%startlon,           &
                                 proj%nlats, proj%deltalon, proj%earth_radius
    else if (proj%iproj == IPROJ_POLAR_STEREOGRAPHIC) then ! Polar stereographic
      read(iunit, iostat=iostat) proj%startloc, proj%startlat, proj%startlon,           &
                                 proj%xlonc, proj%truelat1, proj%earth_radius
    else
      error stop 'ERROR: unsupported map projection !'
    end if
    if (iostat /= 0) then
      error stop 'ERROR: can not read map projection from WPS intermediate format file!'
    end if

    read(iunit, iostat=iostat) proj%is_wind_grid_rel
    if (iostat /= 0) then
      error stop 'ERROR: can not read wind rotation flag from WPS intermediate format file!'
    end if

    if (.not. allocated(field%slab)) then
      allocate(field%slab(field%nx, field%ny))
    end if

    ! Read 2-d array of data
    read(iunit, iostat=iostat) field%slab
    if (iostat /= 0) then
      error stop 'ERROR: can not read slab data from WPS intermediate format file!'
    end if

    call self%init(proj, field)

  end subroutine read_record

  subroutine write_record(self, iunit)

    implicit none
    class(wpsim_record), intent(in)    :: self
    integer, intent(in)                :: iunit

    integer                            :: iostat

    write(unit=iunit, iostat=iostat) self%field%version
    if (iostat /= 0) then
      error stop 'ERROR: can not write format version to WPS intermediate format file!'
    endif

    write(iunit, iostat=iostat) self%field%hdate, self%field%xfcst, self%field%map_source, self%field%field,      &
                                self%field%units, self%field%desc, self%field%xlvl, self%field%nx, self%field%ny, &
                                self%proj%iproj
    if (iostat /= 0) then
      error stop 'ERROR: can not write metadata to WPS intermediate format file!'
    end if

    if (self%proj%iproj == IPROJ_LATLON) then ! Cylindrical equidistant (lat/lon)
      write(iunit, iostat=iostat) self%proj%startloc, self%proj%startlat, self%proj%startlon,           &
                                  self%proj%deltalat, self%proj%deltalon, self%proj%earth_radius
    else if (self%proj%iproj == IPROJ_MERCATOR) then ! Mercator
      write(iunit, iostat=iostat) self%proj%startloc, self%proj%startlat, self%proj%startlon,           &
                                  self%proj%dx, self%proj%dy, self%proj%truelat1, self%proj%earth_radius
    else if (self%proj%iproj == IPROJ_LAMBERT_CONFORMAL) then ! Lambert conformal
      write(iunit, iostat=iostat) self%proj%startloc, self%proj%startlat, self%proj%startlon,           &
                                  self%proj%dx, self%proj%dy, self%proj%xlonc, self%proj%truelat1,      &
                                  self%proj%truelat2, self%proj%earth_radius
    else if (self%proj%iproj == IPROJ_GAUSSIAN) then ! Gaussian
      write(iunit, iostat=iostat) self%proj%startloc, self%proj%startlat, self%proj%startlon,           &
                                  self%proj%nlats, self%proj%deltalon, self%proj%earth_radius
    else if (self%proj%iproj == IPROJ_POLAR_STEREOGRAPHIC) then ! Polar stereographic
      write(iunit, iostat=iostat) self%proj%startloc, self%proj%startlat, self%proj%startlon,           &
                                  self%proj%xlonc, self%proj%truelat1, self%proj%earth_radius
    else
      error stop 'ERROR: unsupported map projection!'
    end if
    if (iostat /= 0) then
      error stop 'ERROR: can not write map projection to WPS intermediate format file!'
    end if

    write(iunit, iostat=iostat) self%proj%is_wind_grid_rel
    if (iostat /= 0) then
      error stop 'ERROR: can not write wind rotation flag to WPS intermediate format file!'
    end if

    ! Write 2-d array of data
    write(iunit, iostat=iostat) self%field%slab
    if (iostat /= 0) then
      error stop 'ERROR: can not write slab data to WPS intermediate format file!'
    end if

  end subroutine write_record

  subroutine write_formatted(self, unit, iotype, v_list, iostat, iomsg)

    implicit none
    class(wpsim_record), intent(in) :: self      !< The string.
    integer, intent(in)             :: unit      !< Logical unit.
    character(len=*), intent(in)    :: iotype    !< Edit descriptor.
    integer, intent(in)             :: v_list(:) !< Edit descriptor list.
    integer, intent(out)            :: iostat    !< IO status code.
    character(len=*), intent(inout) :: iomsg     !< IO status message.

    write(unit, *, iostat=iostat) '================================================', new_line('A')
    write(unit, *, iostat=iostat) ' FIELD = ', trim(self%field%field), new_line('A')
    write(unit, *, iostat=iostat) ' UNITS = ', trim(self%field%units), ' DESCRIPTION = ', trim(self%field%desc), new_line('A')
    write(unit, *, iostat=iostat) ' DATE = ', trim(self%field%hdate), ' FCST = ', self%field%xfcst, new_line('A')
    write(unit, *, iostat=iostat) ' SOURCE = ', trim(self%field%map_source), new_line('A')
    write(unit, *, iostat=iostat) ' LEVEL = ', self%field%xlvl, new_line('A')
    write(unit, *, iostat=iostat) ' I,J DIMS = ', self%field%nx, self%field%ny, new_line('A')
    if (self%proj%iproj == IPROJ_LATLON) then ! Cylindrical equidistant (lat/lon)
      write(unit, *, iostat=iostat) ' IPROJ = ', self%proj%iproj, ' PROJECTION = LAT LON', new_line('A')
      write(unit, *, iostat=iostat) '   REF_X, REF_Y = ', 1.0, 1.0, new_line('A')
      write(unit, *, iostat=iostat) '   REF_LAT, REF_LON = ', self%proj%startlat, self%proj%startlon, new_line('A')
      write(unit, *, iostat=iostat) '   DLAT, DLON = ', self%proj%deltalat, self%proj%deltalon, new_line('A')
    else if (self%proj%iproj == IPROJ_MERCATOR) then ! Mercator
      write(unit, *, iostat=iostat) ' IPROJ = ', self%proj%iproj, ' PROJECTION = MERCATOR', new_line('A')
      write(unit, *, iostat=iostat) '   REF_X, REF_Y = ', 1.0, 1.0, new_line('A')
      write(unit, *, iostat=iostat) '   REF_LAT, REF_LON = ', self%proj%startlat, self%proj%startlon, new_line('A')
      write(unit, *, iostat=iostat) '   DX, DY = ', self%proj%dx, self%proj%dy, new_line('A')
      write(unit, *, iostat=iostat) '   TRUELAT1 = ', self%proj%truelat1, new_line('A')
    else if (self%proj%iproj == IPROJ_LAMBERT_CONFORMAL) then ! Lambert conformal
      write(unit, *, iostat=iostat) ' IPROJ = ', self%proj%iproj, ' PROJECTION = LAMBERT', new_line('A')
      write(unit, *, iostat=iostat) '   REF_X, REF_Y = ', 1.0, 1.0, new_line('A')
      write(unit, *, iostat=iostat) '   REF_LAT, REF_LON = ', self%proj%startlat, self%proj%startlon, new_line('A')
      write(unit, *, iostat=iostat) '   DX, DY = ', self%proj%dx, self%proj%dy, new_line('A')
      write(unit, *, iostat=iostat) '   XLONC = ', self%proj%xlonc, new_line('A')
      write(unit, *, iostat=iostat) '   TRUELAT1 = ', self%proj%truelat1, new_line('A')
      write(unit, *, iostat=iostat) '   TRUELAT2 = ', self%proj%truelat2, new_line('A')
    else if (self%proj%iproj == IPROJ_GAUSSIAN) then ! Gaussian
      write(unit, *, iostat=iostat) ' IPROJ = ', self%proj%iproj, ' PROJECTION = GAUSSIAN', new_line('A')
      write(unit, *, iostat=iostat) '   REF_X, REF_Y = ', 1.0, 1.0, new_line('A')
      write(unit, *, iostat=iostat) '   REF_LAT, REF_LON = ', self%proj%startlat, self%proj%startlon, new_line('A')
      write(unit, *, iostat=iostat) '   NLATS = ', self%proj%nlats, new_line('A')
    else if (self%proj%iproj == IPROJ_POLAR_STEREOGRAPHIC) then ! Polar stereographic
      write(unit, *, iostat=iostat) ' IPROJ = ', self%proj%iproj, ' PROJECTION = POLAR STEREOGRAPHIC', new_line('A')
      write(unit, *, iostat=iostat) '   REF_X, REF_Y = ', 1.0, 1.0, new_line('A')
      write(unit, *, iostat=iostat) '   REF_LAT, REF_LON = ', self%proj%startlat, self%proj%startlon, new_line('A')
      write(unit, *, iostat=iostat) '   XLONC = ', self%proj%xlonc, new_line('A')
      write(unit, *, iostat=iostat) '   TRUELAT1 = ', self%proj%truelat1, new_line('A')
    end if
    write(unit, *, iostat=iostat) '   EARTH_RADIUS = ', self%proj%earth_radius, new_line('A')
    write(unit, *, iostat=iostat) ' DATA(1,1) = ', self%field%slab(1, 1), new_line('A')

  end subroutine write_formatted

end module wpsim_fields