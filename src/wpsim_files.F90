module wpsim_files
  use wpsim_constants
  use wpsim_projection
  use wpsim_fields

  implicit none
  private
  public :: wpsim_file

  type :: wpsim_file
    private
    character(len=24)                :: hdate
    character(len=MAX_FILENAME_LEN)  :: dir
    character(len=MAX_FILENAME_LEN)  :: filename
    character(len=MAX_FILENAME_LEN)  :: prefix
    integer                          :: iunit
    integer                          :: mode ! 1: read, 2: write
    type(wpsim_record_link), pointer :: record_link
  contains
    procedure, public, pass(self)    :: create  => create_file
    procedure, public, pass(self)    :: open    => open_file
    procedure, public, pass(self)    :: close   => close_file
    procedure, public, pass(self)    :: read    => read_records
    procedure, public, pass(self)    :: print   => print_records
    procedure, public, pass(self)    :: write   => write_records
    procedure, private, pass(self)   :: release => release_link
  end type wpsim_file

contains

  subroutine create_file(self, file, dir, date, prefix)

    implicit none
    class(wpsim_file), intent(inout)       :: self
    character(len=*), intent(in), optional :: file
    character(len=*), intent(in), optional :: dir
    character(len=*), intent(in), optional :: date
    character(len=*), intent(in), optional :: prefix

    integer                                :: iostat

    if (present(file)) then
      self%filename = trim(file)
    else
      if (.not. present(dir) .or. .not. present(date)) then
        error stop "ERROR: either filename or both dir and date must be provided."
      end if
      self%dir   = trim(dir)
      self%hdate = trim(date)
      if (len_trim(self%hdate) > 19) then
        error stop "ERROR: datetime format must be YYYY-MM-DD_hh:mm:ss"
      end if
      if (present(prefix)) then
        self%prefix = trim(prefix)
      else
        self%prefix = 'FILE:'
      end if
      self%filename = trim(self%dir)//"/"//trim(self%prefix)//self%hdate
    end if
    self%mode = 2

    open(newunit=self%iunit, file=self%filename, form='unformatted', action='write', iostat=iostat)
    if (iostat /= 0) then
      error stop "ERROR: can not open WPS intermediate format file!"
    end if

  end subroutine create_file

  subroutine open_file(self, file, dir, date, prefix)

    implicit none
    class(wpsim_file), intent(inout)       :: self
    character(len=*), intent(in), optional :: file
    character(len=*), intent(in), optional :: dir
    character(len=*), intent(in), optional :: date
    character(len=*), intent(in), optional :: prefix

    integer                                :: iostat
    logical                                :: exist

    if (present(file)) then
      self%filename = trim(file)
    else
      if (.not. present(dir) .or. .not. present(date)) then
        error stop "ERROR: Either filename or both dir and date must be provided."
      end if
      self%dir   = trim(dir)
      self%hdate = trim(date)
      if (len_trim(self%hdate) > 19) then
        error stop "ERROR: datetime format must be YYYY-MM-DD_hh:mm:ss"
      end if
      if (present(prefix)) then
        self%prefix = trim(prefix)
      else
        self%prefix = 'FILE:'
      end if
      self%filename = trim(self%dir)//"/"//trim(self%prefix)//self%hdate
    end if
    self%mode = 1

    inquire(file=self%filename, exist=exist)
    if (.not. exist) then
      error stop "ERROR: File "//trim(self%filename)//' does not exist!'
    end if

    open(newunit=self%iunit, file=self%filename, form='unformatted', action='read', iostat=iostat)
    if (iostat /= 0) then
      error stop "ERROR: can not open WPS intermediate format file!"
    end if

  end subroutine open_file

  subroutine close_file(self)

    implicit none
    class(wpsim_file), intent(inout) :: self

    integer                          :: iostat

    if (self%mode == 1) call self%release()

    close(unit=self%iunit, iostat=iostat)
    if (iostat /= 0) then
      error stop "ERROR: can not close WPS intermediate format file!"
    end if

  end subroutine close_file

  subroutine read_records(self)

    implicit none
    class(wpsim_file), intent(inout) :: self

    integer                          :: iostat
    type(wpsim_record)               :: record
    type(wpsim_record_link), pointer :: record_link_pointer

    allocate(self%record_link)
    self%record_link%next => null()
    record_link_pointer => self%record_link
    do while (.true.)
      call record%read(self%iunit, iostat)
      if (iostat /= 0) exit
      record_link_pointer%record = record
      allocate(record_link_pointer%next)
      record_link_pointer => record_link_pointer%next
      record_link_pointer%next => null()
    end do

  end subroutine read_records

  subroutine print_records(self, n)

    implicit none
    class(wpsim_file), intent(in)    :: self
    integer, intent(in), optional    :: n ! the number of fields to write, if not provided, write all fields

    type(wpsim_record_link), pointer :: record_link_pointer
    integer                          :: i
    integer                          :: limit

    if (present(n)) then
      limit = n
    else
      limit = huge(0)
    end if

    i = 1
    record_link_pointer => self%record_link
    do while (.true.)
      write(*, *) record_link_pointer%record
      record_link_pointer => record_link_pointer%next
      i = i + 1
      if (.not. associated(record_link_pointer%next) .or. i > limit) exit
    end do

  end subroutine print_records

  subroutine write_records(self, proj, field)

    implicit none
    class(wpsim_file), intent(in)    :: self
    type(wpsim_proj), intent(in)     :: proj
    class(wpsim_field), intent(in)   :: field

    type(wpsim_record)               :: record
    type(wpsim_field2d), allocatable :: field2d(:)
    integer                          :: field_size
    integer                          :: i

    select type (field)
    type is (wpsim_field2d)
      call record%init(proj, field)
      call record%write(self%iunit)
    type is (wpsim_field3d)
      field2d = field%tofields()
      field_size = size(field2d)
      do i = 1, field_size
        call record%init(proj, field2d(i))
        call record%write(self%iunit)
      end do
    type is (wpsim_field3d_soil)
      field2d = field%tofields()
      field_size = size(field2d)
      do i = 1, field_size
        call record%init(proj, field2d(i))
        call record%write(self%iunit)
      end do
    end select

  end subroutine write_records

  subroutine release_link(self)

    implicit none
    class(wpsim_file), intent(inout) :: self

    type(wpsim_record_link), pointer :: record_link_pointer

    do while (.true.)
      record_link_pointer => self%record_link%next
      deallocate(self%record_link)
      self%record_link => record_link_pointer
      if (.not. associated(record_link_pointer)) exit
    end do

  end subroutine release_link

end module wpsim_files