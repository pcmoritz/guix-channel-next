(define-module (channel-next packages)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix gexp)
  #:use-module (guix git-download)
  #:use-module (guix packages)
  #:use-module (guix search-paths)
  #:use-module (guix utils)
  #:use-module (guix build-system trivial)
  #:use-module (guix build-system gnu)
  #:use-module (guix build-system python)
  #:use-module (guix build-system pyproject)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (gnu packages)
  #:use-module (gnu packages base)
  #:use-module (gnu packages bash)
  #:use-module (gnu packages compression)
  #:use-module (gnu packages python)
  #:use-module (gnu packages ninja)
  #:use-module (gnu packages python-build)
  #:use-module (gnu packages python-web)
  #:use-module (gnu packages django)
  #:use-module (gnu packages dbm)
  #:use-module (gnu packages libffi)
  #:use-module (gnu packages pkg-config)
  #:use-module (gnu packages readline)
  #:use-module (gnu packages sqlite)
  #:use-module (gnu packages tcl)
  #:use-module (gnu packages tls)
  #:use-module (gnu packages xml))

(define-public python-3.12-latest
  (package
    (name "python-latest")
    (version "3.12.2")
    (source
     (origin
       (method url-fetch)
       (uri (string-append "https://www.python.org/ftp/python/" version
                           "/Python-" version ".tar.xz"))
       (sha256
        (base32 "0w6qyfhc912xxav9x9pifwca40b4l49vy52wai9j0gc1mhni2a5y"))
       (patches (search-patches "python-3-deterministic-build-info.patch"
                                "python-3.12-fix-tests.patch"
                                "python-3-hurd-configure.patch"))
       (modules '((guix build utils)))
       (snippet '(begin
                   ;; Delete the bundled copy of libexpat.
                   (delete-file-recursively "Modules/expat")
                   (substitute* "Modules/Setup"
                     ;; Link Expat instead of embedding the bundled one.
                     (("^#pyexpat.*")
                      "pyexpat pyexpat.c -lexpat\n"))
                   ;; Delete windows binaries
                   (for-each delete-file
                             (find-files "Lib/distutils/command" "\\.exe$"))))))
    (outputs '("out" "tk" ;tkinter; adds 50 MiB to the closure
               "idle")) ;programming environment; weighs 5MB
    (build-system gnu-build-system)
    (arguments
     `(#:tests? #f
       #:test-target "test"
       #:configure-flags (list "--enable-shared" ;allow embedding
                               "--with-system-expat" ;for XML support
                               "--with-system-ffi" ;build ctypes
                               "--with-ensurepip=install" ;install pip and setuptools
                               "--with-computed-gotos" ;main interpreter loop optimization
                               "--enable-unicode=ucs4"
                               "--without-static-libpython"
                               "--enable-loadable-sqlite-extensions"

                               ;; FIXME: These flags makes Python significantly faster,
                               ;; but leads to non-reproducible binaries.
                               ;; "--with-lto"   ;increase size by 20MB, but 15% speedup
                               ;; "--enable-optimizations"

                               ;; Prevent the installed _sysconfigdata.py from retaining
                               ;; a reference to coreutils.
                               "INSTALL=install -c"
                               "MKDIR_P=mkdir -p"

                               ;; Disable runtime check failing if cross-compiling, see:
                               ;; https://lists.yoctoproject.org/pipermail/poky/2013-June/008997.html
                               ,@(if (%current-target-system)
                                     '("ac_cv_buggy_getaddrinfo=no"
                                       "ac_cv_file__dev_ptmx=no"
                                       "ac_cv_file__dev_ptc=no")
                                     '())
                               ;; -fno-semantic-interposition reinstates some
                               ;; optimizations by gcc leading to around 15% speedup.
                               ;; This is the default starting from python 3.10.
                               "CFLAGS=-fno-semantic-interposition"
                               (string-append "LDFLAGS=-Wl,-rpath="
                                              (assoc-ref %outputs "out")
                                              "/lib"
                                              " -fno-semantic-interposition"))
       ;; With no -j argument tests use all available cpus, so provide one.
       #:make-flags (list (string-append (format #f "TESTOPTS=-j~d"
                                                 (parallel-job-count))
                           ;; those tests fail on low-memory systems
                           " --exclude"
                           " test_mmap"
                           " test_socket"
                           " test_threading"
                           " test_asyncio"
                           " test_shutdown"
                           ,@(if (system-hurd?)
                                 '(" test_posix" ;multiple errors
                                   " test_time"
                                   " test_pty"
                                   " test_shutil"
                                   " test_tempfile" ;chflags: invalid argument:
                                   ;; tbv14c9t/dir0/dir0/dir0/test0.txt
                                   " test_os" ;stty: 'standard input':
                                   ;; Inappropriate ioctl for device
                                   " test_openpty" ;No such file or directory
                                   " test_selectors" ;assertEqual(NUM_FDS // 2, len(fds))
                                   ;; 32752 != 4
                                   " test_compileall" ;multiple errors
                                   " test_poll" ;list index out of range
                                   " test_subprocess" ;runs over 10min
                                   " test_asyncore" ;multiple errors
                                   " test_threadsignals"
                                   " test_eintr" ;Process return code is -14
                                   " test_io" ;multiple errors
                                   " test_logging"
                                   " test_signal"
                                   " test_flags" ;ERROR
                                   " test_bidirectional_pty"
                                   " test_create_unix_connection"
                                   " test_unix_sock_client_ops"
                                   " test_open_unix_connection"
                                   " test_open_unix_connection_error"
                                   " test_read_pty_output"
                                   " test_write_pty"
                                   " test_concurrent_futures" ;freeze
                                   " test_venv" ;freeze
                                   " test_multiprocessing_forkserver" ;runs over 10min
                                   " test_multiprocessing_spawn" ;runs over 10min
                                   " test_builtin"
                                   " test_capi"
                                   " test_dbm_ndbm"
                                   " test_exceptions"
                                   " test_faulthandler"
                                   " test_getopt"
                                   " test_importlib"
                                   " test_json"
                                   " test_multiprocessing_fork"
                                   " test_multiprocessing_main_handling"
                                   " test_pdb "
                                   " test_regrtest"
                                   " test_sqlite")
                                 '())))

       #:modules ((ice-9 ftw)
                  (ice-9 match)
                  (guix build utils)
                  (guix build gnu-build-system))

       #:phases (modify-phases %standard-phases
                  ,@(if (system-hurd?)
                        `((add-after 'unpack
                                     'disable-multi-processing
                                     (lambda _
                                       (substitute* "Makefile.pre.in"
                                         (("-j0")
                                          "-j1")))))
                        '())
                  (add-before 'configure 'patch-lib-shells
                    (lambda _
                      ;; This variable is used in setup.py to enable cross compilation
                      ;; specific switches. As it is not set properly by configure
                      ;; script, set it manually.
                      ,@(if (%current-target-system)
                            '((setenv "_PYTHON_HOST_PLATFORM" ""))
                            '())
                      ;; Filter for existing files, since some may not exist in all
                      ;; versions of python that are built with this recipe.
                      (substitute* (filter file-exists?
                                           '("Lib/subprocess.py"
                                             "Lib/popen2.py"
                                             "Lib/distutils/tests/test_spawn.py"
                                             "Lib/test/support/__init__.py"
                                             "Lib/test/test_subprocess.py"))
                        (("/bin/sh")
                         (which "sh")))))
                  (add-before 'configure 'do-not-record-configure-flags
                    (lambda* (#:key configure-flags #:allow-other-keys)
                      ;; Remove configure flags from the installed '_sysconfigdata.py'
                      ;; and 'Makefile' so we don't end up keeping references to the
                      ;; build tools.
                      ;;
                      ;; Preserve at least '--with-system-ffi' since otherwise the
                      ;; thing tries to build libffi, fails, and we end up with a
                      ;; Python that lacks ctypes.
                      (substitute* "configure"
                        (("^CONFIG_ARGS=.*$")
                         (format #f "CONFIG_ARGS='~a'\n"
                                 (if (member "--with-system-ffi"
                                             configure-flags)
                                     "--with-system-ffi" ""))))))
                  (add-before 'check 'pre-check
                    (lambda _
                      ;; 'Lib/test/test_site.py' needs a valid $HOME
                      (setenv "HOME"
                              (getcwd))))
                  (add-after 'unpack 'set-source-file-times-to-1980
                    ;; XXX One of the tests uses a ZIP library to pack up some of the
                    ;; source tree, and fails with "ZIP does not support timestamps
                    ;; before 1980".  Work around this by setting the file times in the
                    ;; source tree to sometime in early 1980.
                    (lambda _
                      (let ((circa-1980 (* 10 366 24 60 60)))
                        (ftw "."
                             (lambda (file stat flag)
                               (utime file circa-1980 circa-1980) #t)))))
                  (add-after 'unpack 'remove-windows-binaries
                    (lambda _
                      ;; Delete .exe from embedded .whl (zip) files
                      (for-each (lambda (whl)
                                  (let ((dir "whl-content")
                                        (circa-1980 (* 10 366 24 60 60)))
                                    (mkdir-p dir)
                                    (with-directory-excursion dir
                                      (let ((whl (string-append "../" whl)))
                                        (invoke "unzip" whl)
                                        (for-each delete-file
                                                  (find-files "." "\\.exe$"))
                                        (delete-file whl)
                                        ;; Reset timestamps to prevent them from ending
                                        ;; up in the Zip archive.
                                        (ftw "."
                                             (lambda (file stat flag)
                                               (utime file circa-1980
                                                      circa-1980) #t))
                                        (apply invoke "zip" "-X" whl
                                               (find-files "."
                                                           #:directories? #t))))
                                    (delete-file-recursively dir)))
                                (find-files "Lib/ensurepip" "\\.whl$"))))
                  (add-after 'install 'remove-tests
                    ;; Remove 25 MiB of unneeded unit tests.  Keep test_support.*
                    ;; because these files are used by some libraries out there.
                    (lambda* (#:key outputs #:allow-other-keys)
                      (let ((out (assoc-ref outputs "out")))
                        (match (scandir (string-append out "/lib")
                                        (lambda (name)
                                          (string-prefix? "python" name)))
                          ((pythonX.Y)
                           (let ((testdir (string-append out "/lib/" pythonX.Y
                                                         "/test")))
                             (with-directory-excursion testdir
                               (for-each delete-file-recursively
                                         (scandir testdir
                                                  (match-lambda
                                                    ((or "." "..")
                                                     #f)
                                                    ("support" #f)
                                                    (file (not (string-prefix?
                                                                "test_support."
                                                                file))))))
                               (call-with-output-file "__init__.py"
                                 (const #t))))
                           (let ((libdir (string-append out "/lib/" pythonX.Y)))
                             (for-each (lambda (directory)
                                         (let ((dir (string-append libdir "/"
                                                                   directory)))
                                           (when (file-exists? dir)
                                             (delete-file-recursively dir))))
                                       '("email/test" "ctypes/test"
                                         "unittest/test"
                                         "tkinter/test"
                                         "sqlite3/test"
                                         "bsddb/test"
                                         "lib-tk/test"
                                         "json/tests"
                                         "distutils/tests"))))))))
                  (add-after 'remove-tests 'move-tk-inter
                    (lambda* (#:key outputs inputs #:allow-other-keys)
                      ;; When Tkinter support is built move it to a separate output so
                      ;; that the main output doesn't contain a reference to Tcl/Tk.
                      (let ((out (assoc-ref outputs "out"))
                            (tk (assoc-ref outputs "tk")))
                        (when tk
                          (match (find-files out "tkinter.*\\.so")
                            ((tkinter.so)
                             ;; The .so is in OUT/lib/pythonX.Y/lib-dynload, but we
                             ;; want it under TK/lib/pythonX.Y/site-packages.
                             (let* ((len (string-length out))
                                    (target (string-append tk "/"
                                                           (string-drop (dirname
                                                                         (dirname
                                                                          tkinter.so))
                                                                        len)
                                                           "/site-packages")))
                               (install-file tkinter.so target)
                               (delete-file tkinter.so))))
                          ;; Remove explicit store path references.
                          (let ((tcl (assoc-ref inputs "tcl"))
                                (tk (assoc-ref inputs "tk")))
                            (substitute* (find-files (string-append out "/lib")
                                          "^(_sysconfigdata_.*\\.py|Makefile)$")
                              (((string-append "-L" tk "/lib"))
                               "")
                              (((string-append "-L" tcl "/lib"))
                               "")))))))
                  (add-after 'move-tk-inter 'move-idle
                    (lambda* (#:key outputs #:allow-other-keys)
                      ;; when idle is built, move it to a separate output to save some
                      ;; space (5MB)
                      (let ((out (assoc-ref outputs "out"))
                            (idle (assoc-ref outputs "idle")))
                        (when idle
                          (for-each (lambda (file)
                                      (let ((target (string-append idle
                                                                   "/bin/"
                                                                   (basename
                                                                    file))))
                                        (install-file file
                                                      (dirname target))
                                        (delete-file file)))
                                    (find-files (string-append out "/bin")
                                                "^idle"))
                          (match (find-files out "^idlelib$"
                                             #:directories? #t)
                            ((idlelib)
                             (let* ((len (string-length out))
                                    (target (string-append idle "/"
                                                           (string-drop
                                                            idlelib len)
                                                           "/site-packages")))
                               (mkdir-p (dirname target))
                               (rename-file idlelib target))))))))
                  (add-after 'move-idle 'rebuild-bytecode
                    (lambda* (#:key outputs #:allow-other-keys)
                      (let ((out (assoc-ref outputs "out")))
                        ;; Disable hash randomization to ensure the generated .pycs
                        ;; are reproducible.
                        (setenv "PYTHONHASHSEED" "0")

                        (for-each (lambda (output)
                                    ;; XXX: Delete existing pycs generated by the build
                                    ;; system beforehand because the -f argument does
                                    ;; not necessarily overwrite all files, leading to
                                    ;; indeterministic results.
                                    (for-each (lambda (pyc)
                                                (delete-file pyc))
                                              (find-files output "\\.pyc$"))

                                    (apply invoke
                                           `(,,(if (%current-target-system)
                                                   "python3"
                                                   '(string-append out
                                                     "/bin/python3")) "-m"
                                             "compileall"
                                             "-o"
                                             "0"
                                             "-o"
                                             "1"
                                             "-o"
                                             "2"
                                             "-f" ;force rebuild
                                             "--invalidation-mode=unchecked-hash"
                                             ;; Don't build lib2to3, because it's
                                             ;; Python 2 code.
                                             "-x"
                                             "lib2to3/.*"
                                             ,output)))
                                  (map cdr outputs)))))
                  (add-before 'check 'set-TZDIR
                    (lambda* (#:key inputs native-inputs #:allow-other-keys)
                      ;; test_email requires the Olson time zone database.
                      (setenv "TZDIR"
                              (string-append (assoc-ref (or native-inputs
                                                            inputs) "tzdata")
                                             "/share/zoneinfo"))))
                  (add-after 'install 'install-sitecustomize.py
                    ,(customize-site version)))))
    (inputs (list bzip2
                  expat
                  gdbm
                  libffi ;for ctypes
                  sqlite ;for sqlite extension
                  openssl
                  readline
                  zlib
                  tcl
                  tk)) ;for tkinter
    (native-inputs `(("tzdata" ,tzdata-for-tests)
                     ("unzip" ,unzip)
                     ("zip" ,(@ (gnu packages compression) zip))
                     ("pkg-config" ,pkg-config)
                     ("sitecustomize.py" ,(local-file (search-auxiliary-file
                                                       "python/sitecustomize.py")))
                     ;; When cross-compiling, a native version of Python itself is needed.
                     ,@(if (%current-target-system)
                           `(("python" ,this-package)
                             ("which" ,which))
                           '())))
    (native-search-paths
     (list (guix-pythonpath-search-path version)
           ;; Used to locate tzdata by the zoneinfo module introduced in
           ;; Python 3.9.
           (search-path-specification
            (variable "PYTHONTZPATH")
            (files (list "share/zoneinfo")))))
    (home-page "https://www.python.org")
    (synopsis "High-level, dynamically-typed programming language")
    (description
     "Python is a remarkably powerful dynamic programming language that
is used in a wide variety of application domains.  Some of its key
distinguishing features include: clear, readable syntax; strong
introspection capabilities; intuitive object orientation; natural
expression of procedural code; full modularity, supporting hierarchical
packages; exception-based error handling; and very high level dynamic
data types.")
    (properties '((cpe-name . "python")))
    (license license:psfl)))

(define-public python-wheel-next
  (package
    (name "python-wheel-next")
    (version "0.40.0")
    (source
      (origin
        (method url-fetch)
        (uri (pypi-uri "wheel" version))
        (sha256
         (base32
          "0ww8fgkvwv35ypj4cnngczdwp6agr4qifvk2inb32azfzbrrc4fd"))))
    (build-system python-build-system)
    (arguments
     ;; FIXME: The test suite runs "python setup.py bdist_wheel", which in turn
     ;; fails to find the newly-built bdist_wheel library, even though it is
     ;; available on PYTHONPATH.  What search path is consulted by setup.py?
     '(#:tests? #f))
    (native-inputs
     (list python-setuptools))
    (home-page "https://github.com/pypa/wheel")
    (synopsis "Format for built Python packages")
    (description
     "A wheel is a ZIP-format archive with a specially formatted filename and
the @code{.whl} extension.  It is designed to contain all the files for a PEP
376 compatible install in a way that is very close to the on-disk format.  Many
packages will be properly installed with only the @code{Unpack} step and the
unpacked archive preserves enough information to @code{Spread} (copy data and
scripts to their final locations) at any later time.  Wheel files can be
installed with a newer @code{pip} or with wheel's own command line utility.")
    (license license:expat)))

(define-public meson-next
  (package
    (name "meson-next")
    (version "1.5.2")
    (source (origin
              (method url-fetch)
              (uri (string-append "https://github.com/mesonbuild/meson/"
                                  "releases/download/" version  "/meson-"
                                  version ".tar.gz"))
              (sha256
               (base32
                "02wi62k9w7716xxdgrrx68q89vaq3ncnbpw5ms0g27npn2df0mgr"))))
    (build-system python-build-system)
    (arguments
     '(#:tests? #f                  ;disabled to avoid extra dependencies
       #:phases
           (modify-phases %standard-phases
               ;; Meson calls the various executables in out/bin through the
               ;; Python interpreter, so we cannot use the shell wrapper.
               (replace 'wrap
                 (lambda* (#:key inputs outputs #:allow-other-keys)
                   (substitute* (search-input-file outputs "bin/meson")
                     (("# EASY-INSTALL-ENTRY-SCRIPT")
                      (format #f "\
import sys
sys.path.insert(0, '~a')
# EASY-INSTALL-ENTRY-SCRIPT" (site-packages inputs outputs)))))))))
    (inputs (list python ninja))
    (native-inputs
     (list python-setuptools))
    (home-page "https://mesonbuild.com/")
    (synopsis "Build system designed to be fast and user-friendly")
    (description
     "The Meson build system is focused on user-friendliness and speed.
It can compile code written in C, C++, Fortran, Java, Rust, and other
languages.  Meson provides features comparable to those of the
Autoconf/Automake/make combo.  Build specifications, also known as @dfn{Meson
files}, are written in a custom domain-specific language (@dfn{DSL}) that
resembles Python.")
    (license license:asl2.0)))

(define-public python-mypy-extensions-next
  (package
    (name "python-mypy-extensions-next")
    (version "1.0.0")
    (source (origin
              (method url-fetch)
              (uri (pypi-uri "mypy_extensions" version))
              (sha256
               (base32
                "10h7mwjjfbwxzq7jzaj1pnv9g6laa1k0ckgw72j44160bnazinvm"))))
    (build-system python-build-system)
    (arguments
     `(#:tests? #f)) ;no tests
    (native-inputs
     (list python-setuptools))
    (home-page "https://github.com/python/mypy_extensions")
    (synopsis "Experimental extensions for MyPy")
    (description
     "The @code{python-mypy-extensions} module defines
experimental extensions to the standard @code{typing} module that are
supported by the MyPy typechecker.")
    (license license:expat)))

;;; Tests are left out in the main package to avoid cycles.
;; XXX: When updating, solve comment in python-cu2qu.
(define-public python-fonttools-minimal-next
  (hidden-package
   (package
     (name "python-fonttools-minimal-next")
     (version "4.39.3")
     (source (origin
               (method url-fetch)
               (uri (pypi-uri "fonttools" version ".zip"))
               (sha256
                (base32
                 "1msibi5cmi5znykkg66dq7xshl07lkqjxhrz5hcipqvlggsvjd4j"))))
     (build-system python-build-system)
     (native-inputs
      (list unzip
	    python-setuptools))
     (arguments '(#:tests? #f))
     (home-page "https://github.com/fonttools/fonttools")
     (synopsis "Tools to manipulate font files")
     (description
      "FontTools/TTX is a library to manipulate font files from Python.  It
supports reading and writing of TrueType/OpenType fonts, reading and writing
of AFM files, reading (and partially writing) of PS Type 1 fonts.  The package
also contains a tool called “TTX” which converts TrueType/OpenType fonts to and
from an XML-based format.")
     (license license:expat))))

(define-public python-iniconfig-next
  (package
    (name "python-iniconfig-next")
    (version "1.1.1")
    (source
     (origin
       (method url-fetch)
       (uri (pypi-uri "iniconfig" version))
       (sha256
        (base32
         "0ckzngs3scaa1mcfmsi1w40a1l8cxxnncscrxzjjwjyisx8z0fmw"))))
    (build-system python-build-system)
    (native-inputs
     (list python-setuptools))
    (home-page "https://github.com/RonnyPfannschmidt/iniconfig")
    (synopsis "Simple INI-file parser")
    (description "The @code{iniconfig} package provides a small and simple
     INI-file parser module having a unique set of features ; @code{iniconfig}
     @itemize
     @item maintains the order of sections and entries              ;
     @item supports multi-line values with or without line-continuations ;
     @item supports \"#\" comments everywhere                            ;
     @item raises errors with proper line-numbers                        ;
     @item raises an error when two sections have the same name.
     @end itemize")
    (license license:expat)))

(define-public python-appdirs-next
  (package
    (name "python-appdirs-next")
    (version "1.4.4")
    (source
      (origin
        (method url-fetch)
        (uri (pypi-uri "appdirs" version))
        (sha256
          (base32
            "0hfzmwknxqhg20aj83fx80vna74xfimg8sk18wb85fmin9kh2pbx"))))
    (build-system python-build-system)
    (native-inputs
     (list python-setuptools))
    (home-page "https://github.com/ActiveState/appdirs")
    (synopsis
      "Determine platform-specific dirs, e.g. a \"user data dir\"")
    (description
      "This module provides a portable way of finding out where user data
should be stored on various operating systems.")
    (license license:expat)))

(define-public python-elementpath-next
  (package
    (name "python-elementpath-next")
    (version "2.0.3")
    (source
     (origin
       (method url-fetch)
       (uri (pypi-uri "elementpath" version))
       (sha256
        (base32
         "1kxx573ywqfh6j6aih2i6hhsya6kz79qq4bgz6yskwk6b18jyr8z"))))
    (build-system python-build-system)
    ;; The test suite is not run, to avoid a dependency cycle with
    ;; python-xmlschema.
    (arguments `(#:tests? #f))
    (native-inputs
     (list python-setuptools))
    (home-page
     "https://github.com/sissaschool/elementpath")
    (synopsis
     "XPath 1.0/2.0 parsers and selectors for ElementTree and lxml")
    (description
     "The proposal of this package is to provide XPath 1.0 and 2.0 selectors
for Python's ElementTree XML data structures, both for the standard
ElementTree library and for the @uref{http://lxml.de, lxml.etree} library.
For lxml.etree this package can be useful for providing XPath 2.0 selectors,
because lxml.etree already has its own implementation of XPath 1.0.")
    (license license:expat)))

(define-public python-pluggy-next
  (package
    (name "python-pluggy")
    (version "1.6.0")
    (source
     (origin
       (method url-fetch)
       (uri (pypi-uri "pluggy" version))
       (sha256
        (base32 "1wr2vnbb7gy9wlz01yvb7rn4iqzd3mwmidk11ywk7395fq5i7k3x"))))
    (build-system pyproject-build-system)
    (arguments
     `(#:tests? #f))
    (native-inputs
     (list python-setuptools-next
           python-setuptools-scm-next
           python-wheel))
    (home-page "https://pypi.org/project/pluggy/")
    (synopsis "Plugin and hook calling mechanism for Python")
    (description
     "Pluggy is an extraction of the plugin manager as used by Pytest but                                                                                                 
stripped of Pytest specific details.")
    (license license:expat)))

(define-public python-docutils-next
  (package
    (name "python-docutils-next")
    (version "0.19")
    (source (origin
              (method url-fetch)
              (uri (pypi-uri "docutils" version))
              (sha256
               (base32
                "1rprvir116g5rz2bgzkzgyn6mv0z8582rz7bgxbpy2y3adkmm69k"))))
    (build-system python-build-system)
    (arguments
     '(#:phases (modify-phases %standard-phases
                  (replace 'check
                    (lambda* (#:key tests? #:allow-other-keys)
                      (if tests?
                          (invoke "python" "test/alltests.py")
                          (format #t "test suite not run~%")))))))
    (native-inputs
     (list python-setuptools))
    (home-page "https://docutils.sourceforge.net/")
    (synopsis "Python Documentation Utilities")
    (description
     "Docutils is a modular system for processing documentation into useful
formats, such as HTML, XML, and LaTeX.  It uses @dfn{reStructuredText}, an
easy to use markup language, for input.

This package provides tools for converting @file{.rst} files to other formats
via commands such as @command{rst2man}, as well as supporting Python code.")
    ;; Most of the source code is public domain, but some source files are
    ;; licensed under the PFSL, BSD 2-clause, and GPLv3+ licenses.
    (license (list license:public-domain license:psfl license:bsd-2 license:gpl3+))))

(define-public python-pycparser-next
  (package
    (name "python-pycparser-next")
    (version "2.21")
    (source
     (origin
      (method url-fetch)
      (uri (pypi-uri "pycparser" version))
      (sha256
       (base32
        "01kjlyn5w2nn2saj8w1rhq7v26328pd91xwgqn32z1zp2bngsi76"))))
    (outputs '("out" "doc"))
    (build-system python-build-system)
    (arguments
     `(#:phases
       (modify-phases %standard-phases
         (replace 'check
           (lambda _
             (invoke "python" "-m" "unittest" "discover")))
         (add-after 'install 'install-doc
           (lambda* (#:key outputs #:allow-other-keys)
             (let* ((data (string-append (assoc-ref outputs "doc") "/share"))
                    (doc (string-append data "/doc/" ,name "-" ,version))
                    (examples (string-append doc "/examples")))
               (mkdir-p examples)
               (for-each (lambda (file)
                           (copy-file (string-append "." file)
                                      (string-append doc file)))
                         '("/README.rst" "/CHANGES" "/LICENSE"))
               (copy-recursively "examples" examples)))))))
    (native-inputs
     (list python-setuptools))
    (home-page "https://github.com/eliben/pycparser")
    (synopsis "C parser in Python")
    (description
     "Pycparser is a complete parser of the C language, written in pure Python
using the PLY parsing library.  It parses C code into an AST and can serve as
a front-end for C compilers or analysis tools.")
    (license license:bsd-3)))

(define-public mallard-ducktype-next
  (package
    (name "mallard-ducktype-next")
    (version "1.0.2")
    (source
     (origin
       (method git-fetch)
       ;; git-reference because tests are not included in pypi source tarball                                                                                             
       ;; https://issues.guix.gnu.org/issue/36755#2                                                                                                                       
       (uri (git-reference
             (url "https://github.com/projectmallard/mallard-ducktype")
             (commit version)))
       (file-name (git-file-name name version))
       (sha256
        (base32
         "1jk9bfz7g04ip78s03b0xak6d54rj4h9zpgadkziy1ji216g6y4c"))))
    (build-system python-build-system)
    (arguments
     '(#:phases
       (modify-phases %standard-phases
         (replace 'check
           (lambda _
             (with-directory-excursion "tests"
               (invoke "sh" "runtests")))))))
    (native-inputs
     (list python-setuptools))
    (home-page "http://projectmallard.org")
    (synopsis "Convert Ducktype to Mallard documentation markup")
    (description
     "Ducktype is a lightweight syntax that can represent all the semantics                                                                                               
of the Mallard XML documentation system.  Ducktype files can be converted to                                                                                              
Mallard using the @command{ducktype} tool.  The yelp-tools package                                                                                                        
provides additional functionality on the produced Mallard documents.")
    (license license:expat)))

(define-public python-django-next
  (package
    (inherit python-django-4.2)
    (name "python-django-next")
    (version "5.2.4")
    (source (origin
              (method url-fetch)
              (uri (pypi-uri "django" version))
              (sha256
               (base32
                "13qdahx511xj1k95hiwd0p2j51z0nfvns68mq3mkx8cg9ww8q8m1"))))
    ;; (propagated-inputs
    ;;  (list python-3.12-nocheck))
    ;; (native-inputs
    ;;  (list python-3.12-nocheck))
    (arguments
     `(#:python ,python-next
       #:test-flags
       (list
        ;; By default tests run in parallel, which may cause various race
        ;; conditions.  Run sequentially for consistent results.
        "--parallel=1"
        ;; The test suite fails as soon as a single test fails.
        "--failfast")
       #:phases
       (modify-phases %standard-phases
         (add-before 'check 'pre-check
           (lambda* (#:key inputs #:allow-other-keys)
             ;; The test-suite tests timezone-dependent functions, thus tzdata
             ;; needs to be available.
             (setenv "TZDIR"
                     (search-input-directory inputs "share/zoneinfo"))

             ;; Disable test for incorrect timezone: it only raises the
             ;; expected error when /usr/share/zoneinfo exists, even though
             ;; the machinery gracefully falls back to TZDIR.  According to
             ;; django/conf/__init__.py, lack of /usr/share/zoneinfo is
             ;; harmless, so just ignore this test.
             (substitute* "tests/settings_tests/tests.py"
               ((".*def test_incorrect_timezone.*" all)
                (string-append "    @unittest.skip('Disabled by Guix')\n"
                               all)))
             ;; avoid filename too long error
             (substitute* "tests/file_storage/tests.py"
                          ((".*def test_extended_length_storage.*" all)
                           (string-append "    @unittest.skip('Disabled by Guix')\n" all)))
             (substitute* "tests/admin_scripts/tests.py"
                          (("test_environ\\[\"PYTHONPATH\"\\] = os\\.pathsep\\.join\\(python_path\\)")
                            "test_environ[\"PYTHONPATH\"] = os.pathsep.join(python_path + sys.path)"))))
         (replace 'check
           (lambda* (#:key tests? test-flags #:allow-other-keys)
             (if tests?
                 (with-directory-excursion "tests"
                   ;; Tests expect PYTHONPATH to contain the root directory.
                   (setenv "PYTHONPATH" "..")
                   (apply invoke "python" "runtests.py" test-flags))
                 (format #t "test suite not run~%"))))
         ;; XXX: The 'wrap' phase adds native inputs as runtime dependencies,
         ;; see <https://bugs.gnu.org/25235>.  The django-admin script typically
         ;; runs in an environment that has Django and its dependencies on
         ;; PYTHONPATH, so just disable the wrapper to reduce the size from
         ;; ~710 MiB to ~203 MiB.
         (delete 'wrap))))
    (propagated-inputs
     (modify-inputs (package-propagated-inputs python-django-4.2)
                    (append python-setuptools-next)
                    (append python-pluggy-next)))))
