program wpsim_dump
  use iso_fortran_env, only: error_unit
  use wpsim_io
  implicit none

  integer             :: argc
  integer             :: arg_length
  character(len=1024) :: filename
  character(len=64)   :: n_string
  integer             :: status
  logical             :: exist
  integer             :: n

  argc = command_argument_count()

  ! Accept one or two arguments
  if (argc < 1 .or. argc > 2) then
    call usage()
    stop 2
  end if

  ! First argument: filename
  call get_command_argument(1, filename, length=arg_length, status=status)

  if (status /= 0 .or. arg_length == 0 .or. arg_length > len(filename)) then
    call usage()
    stop 2
  end if

  inquire(file=trim(filename), exist=exist)
  if (.not. exist) then
    write(error_unit, '(a, a)') 'Error: file not found: ', trim(filename)
    stop 1
  end if

  ! Second argument: optional number of fields
  if (argc == 1) then
    ! Print all fields
    call dump_fields(trim(filename))
  else
    call get_command_argument(2, n_string, length=arg_length, status=status)
    if (status /= 0 .or. arg_length == 0 .or. arg_length > len(n_string)) then
      call usage()
      stop 2
    end if

    call parse_positive_integer(trim(n_string), n, status)
    if (status /= 0) then
      write(error_unit, '(a)') 'Error: n must be a positive integer.'
      call usage()
      stop 2
    end if

    call dump_fields(trim(filename), n)

  end if

contains

  subroutine usage()

    write(error_unit, '(a)') 'Usage: wpsim_dump <filename> [n]'
    write(error_unit, '(a)') ''
    write(error_unit, '(a)') 'Arguments:'
    write(error_unit, '(a)') '  filename    WPS intermediate file'
    write(error_unit, '(a)') '  n           Number of fields to print (optional)'
    write(error_unit, '(a)') ''
    write(error_unit, '(a)') 'Examples:'
    write(error_unit, '(a)') '  wpsim_dump FILE:2013-08-11_00'
    write(error_unit, '(a)') '  wpsim_dump FILE:2013-08-11_00 5'

  end subroutine usage

  subroutine parse_positive_integer(string, value, ierr)

    implicit none
    character(len=*), intent(in)  :: string
    integer,          intent(out) :: value
    integer,          intent(out) :: ierr

    integer                       :: i
    integer                       :: length

    value = 0
    ierr = 1

    length = len_trim(string)

    if (length == 0) return

    ! Only accept decimal digits
    do i = 1, length
      if (string(i:i) < '0' .or. string(i:i) > '9') then
        return
      end if
    end do

    read(string, *, iostat=ierr) value

    if (ierr /= 0) return

    if (value <= 0) then
      ierr = 1
      return
    end if

    ierr = 0

  end subroutine parse_positive_integer

  subroutine dump_fields(file, top_n)

    implicit none
    character(len=*), intent(in)  :: file
    integer, optional, intent(in) :: top_n

    type(wpsim_file)    :: im_file

    call im_file%open(file=file)
    call im_file%read()
    call im_file%print(top_n)
    call im_file%close()

end subroutine dump_fields

end program wpsim_dump