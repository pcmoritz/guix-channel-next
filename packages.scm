(use-modules (guix packages)
             (guix download)
             (guix utils)
             (guix build-system trivial)
             (guix build-system python)
             (guix build-system pyproject)
             ((guix licenses) #:prefix license:)
             (gnu packages bash)
             (gnu packages python)
             (gnu packages python-build)
             (gnu packages python-web)
             (gnu packages django))

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

(define-public python-django-5.2
  (package
    (inherit python-django-4.2)
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
