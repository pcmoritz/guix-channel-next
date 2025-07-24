(define-module (channel-next packages)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix git-download)
  #:use-module (guix utils)
  #:use-module (guix build-system trivial)
  #:use-module (guix build-system python)
  #:use-module (guix build-system pyproject)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (gnu packages bash)
  #:use-module (gnu packages python)
  #:use-module (gnu packages python-build)
  #:use-module (gnu packages python-web)
  #:use-module (gnu packages django))

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
     (list #:tests? #f                  ;disabled to avoid extra dependencies
           #:phases
           #~(modify-phases %standard-phases
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
     `(#:test-flags
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
