#-------------------------------------------------------------------------------
#   This file is part of the Code_Saturne Solver.
#
#   Copyright (C) 2009  EDF
#
#   The Code_Saturne Preprocessor is free software; you can redistribute it
#   and/or modify it under the terms of the GNU General Public License
#   as published by the Free Software Foundation; either version 2 of
#   the License, or (at your option) any later version.
#
#   The Code_Saturne Preprocessor is distributed in the hope that it will be
#   useful, but WITHOUT ANY WARRANTY; without even the implied warranty
#   of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#   GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public Licence
#   along with the Code_Saturne Preprocessor; if not, write to the
#   Free Software Foundation, Inc.,
#   51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
#-------------------------------------------------------------------------------

import fnmatch
import os
import sys
import subprocess
import tempfile

from optparse import OptionParser

import cs_config

#-------------------------------------------------------------------------------

def process_cmd_line(argv):
    """
    Processes the passed command line arguments.

    Input Argument:
      arg -- This can be either a list of arguments as in
             sys.argv[1:] or a string that is similar to the one
             passed on the command line.  If it is a string the
             string is split to create a list of arguments.
    """

    parser = OptionParser(usage="usage: %prog [options]")

    parser.add_option("-t", "--test", dest="test_mode",
                      action="store_true",
                      help="test only, discard compilation result")

    parser.add_option("-f", "--force", dest="force_link",
                      action="store_true",
                      help="force link, even with no source files")

    parser.add_option("-s", "--source", dest="src_dir", type="string",
                      metavar="<src_dir>",
                      help="choose source file directory")

    parser.add_option("-d", "--dest", dest="dest_dir", type="string",
                      metavar="<dest_dir>",
                      help="choose executable file directory")

    parser.add_option("--opt-libs", dest="opt_libs", type="string",
                      metavar="<libs>",
                      help="optional libraries")

    parser.add_option("--syrthes", dest="link_syrthes",
                      action="store_true",
                      help="SYRTHES link")

    parser.set_defaults(test_mode=False)
    parser.set_defaults(force_link=False)
    parser.set_defaults(src_dir=os.getcwd())
    parser.set_defaults(dest_dir=os.getcwd())
    parser.set_defaults(opt_libs="")
    parser.set_defaults(link_syrthes=False)

    (options, args) = parser.parse_args(argv)

    if len(args) > 0:
        parser.print_help()
        sys.exit(1)

    src_dir = os.path.expanduser(options.src_dir)
    src_dir = os.path.expandvars(src_dir)
    src_dir = os.path.abspath(src_dir)
    if not os.path.isdir(src_dir):
        print "Error: %s is not a directory" % src_dir
        sys.exit(1)

    dest_dir = os.path.expanduser(options.dest_dir)
    dest_dir = os.path.expandvars(dest_dir)
    dest_dir = os.path.abspath(dest_dir)
    if not os.path.isdir(dest_dir):
        print "Error: %s is not a directory" % dest_dir
        sys.exit(1)

    return options.test_mode, options.force_link, src_dir, dest_dir, options.opt_libs, options.link_syrthes

#-------------------------------------------------------------------------------

def so_dirs_path(flags):
    """
    Assemble path for shared libraries in nonstandard directories.
    """
    retval = ""
    first = True

    args = flags.split(" ")

    for arg in args:
        if arg[0:2] == '-L' and arg[0:6] != '-L/usr' and arg[0:6] != '-L/lib':
            if first == True:
                retval = " " + cs_config.build.rpath + ":" + arg[2:]
                first = False
            else:
                retval = retval + ":" + arg[2:]

    return retval

#-------------------------------------------------------------------------------

def run_command(cmd):
    """
    Run a command.
    """
    print cmd
    p = subprocess.Popen(cmd,
                         shell=True,
                         stdout=subprocess.PIPE,
                         stderr=subprocess.PIPE)
    output = p.communicate()
    print output[0], output[1]

    return p.returncode

#-------------------------------------------------------------------------------

def compile_and_link(srcdir, destdir, optlibs, force_link):
    """
    Compilation and link function.
    """
    retval = 0

    exec_name = "cs_solver"
    if destdir != None:
        exec_name = os.path.join(destdir, exec_name)

    # Change to temporary directory

    call_dir = os.getcwd()
    temp_dir = tempfile.mkdtemp(suffix=".cs_compile")
    os.chdir(temp_dir)

    # Find files to compile in source path

    dir_files = os.listdir(srcdir)

    c_files = fnmatch.filter(dir_files, '*.c')
    h_files = fnmatch.filter(dir_files, '*.h')
    f_files = fnmatch.filter(dir_files, '*.[fF]90')

    for f in c_files:
        cmd = cs_config.build.cc
        if len(h_files) > 0:
            cmd = cmd + " -I" + srcdir
        cmd = cmd + " -I" + os.path.join(cs_config.dirs.prefix, "include")
        cmd = cmd + " -DHAVE_CONFIG_H"
        cmd = cmd + " " + cs_config.build.cppflags
        cmd = cmd + " " + cs_config.build.cflags
        cmd = cmd + " -c " + os.path.join(srcdir, f)
        if run_command(cmd) != 0:
            retval = 1

    for f in f_files:
        cmd = cs_config.build.fc
        if len(h_files) > 0:
            cmd = cmd + " -I" + srcdir
        cmd = cmd + " -I" + os.path.join(cs_config.dirs.prefix, "include")
        cmd = cmd + " " + cs_config.build.fcflags
        cmd = cmd + " -c " + os.path.join(srcdir, f)
        if run_command(cmd) != 0:
            retval = 1

    if retval == 0 and (force_link or (len(c_files) + len(f_files)) > 0):
        cmd = cs_config.build.cc
        cmd = cmd + " -o " + exec_name
        if (len(c_files) + len(f_files)) > 0:
          cmd = cmd + " *.o"
        cmd = cmd + " -L" + os.path.join(cs_config.dirs.prefix, "lib")
        cmd = cmd + " -lsaturne"
        if len(optlibs) > 0:
            cmd = cmd + " " + optlibs
        cmd = cmd + " " + cs_config.build.ldflags + " " + cs_config.build.libs
        if cs_config.build.rpath != "":
            cmd = cmd + " " + so_dirs_path(cmd)
        if run_command(cmd) != 0:
            retval = 1

    # Cleanup

    for f in os.listdir(temp_dir):
        os.remove(os.path.join(temp_dir, f))

    # Return to original directory

    os.chdir(call_dir)
    os.rmdir(temp_dir)

    return retval

#-------------------------------------------------------------------------------

def compile_and_link_syrthes(srcdir, destdir):
    """
    Compilation and link function.
    """
    retval = 0

    exec_name = "syrthes"
    if destdir != None:
        exec_name = os.path.join(destdir, exec_name)

    # Change to temporary directory

    call_dir = os.getcwd()
    temp_dir = tempfile.mkdtemp(suffix=".cs_compile_syrthes")
    os.chdir(temp_dir)

    # Find files to compile in source path

    dir_files = os.listdir(srcdir)

    c_files = fnmatch.filter(dir_files, '*.c')
    h_files = fnmatch.filter(dir_files, '*.h')
    f_files = fnmatch.filter(dir_files, '*.[fF]')

    for f in c_files:
        cmd = cs_config.build_syrthes.cc
        if len(h_files) > 0:
            cmd = cmd + " -I" + srcdir
        cmd = cmd + " " + cs_config.build_syrthes.cppflags
        cmd = cmd + " " + cs_config.build_syrthes.cflags
        cmd = cmd + " -c " + os.path.join(srcdir, f)
        if run_command(cmd) != 0:
            retval = 1

    for f in f_files:
        cmd = cs_config.build_syrthes.fc
        if len(h_files) > 0:
            cmd = cmd + " -I" + srcdir
        cmd = cmd + " " + cs_config.build_syrthes.cppflags
        cmd = cmd + " " + cs_config.build_syrthes.fcflags
        cmd = cmd + " -c " + os.path.join(srcdir, f)
        if run_command(cmd) != 0:
            retval = 1

    if retval == 0:
        # Link with Code_Saturne C compiler
        cmd = cs_config.build.cc
        cmd = cmd + " -o " + exec_name
        if (len(f_files)) > 0:
          cmd = cmd + " *.o"
        cmd = cmd + " -L" + os.path.join(cs_config.dirs.prefix, "lib")
        cmd = cmd + " -lsyrcs"
        cmd = cmd + " " + cs_config.build_syrthes.ldflags
        cmd = cmd + " " + cs_config.build_syrthes.libs
        if cs_config.build.rpath != "":
            cmd = cmd + " " + so_dirs_path(cmd)
        if run_command(cmd) != 0:
            retval = 1

    # Cleanup

    for f in os.listdir(temp_dir):
        os.remove(os.path.join(temp_dir, f))

    # Return to original directory

    os.chdir(call_dir)
    os.rmdir(temp_dir)

#-------------------------------------------------------------------------------
# Main
#-------------------------------------------------------------------------------

def main(argv):
    """
    Main function.
    """

    test_mode, force_link, src_dir, dest_dir, opt_libs, link_syrthes = process_cmd_line(argv)

    if test_mode == True:
        dest_dir = None

    if link_syrthes == True:
        retcode = compile_and_link_syrthes(src_dir, dest_dir)
    else:
        retcode = compile_and_link(src_dir, dest_dir, opt_libs, force_link)

    sys.exit(retcode)


if __name__ == '__main__':
    main(sys.argv[1:])

#-------------------------------------------------------------------------------
# End
#-------------------------------------------------------------------------------
