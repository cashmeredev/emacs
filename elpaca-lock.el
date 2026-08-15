((ace-link :source "elpaca-menu-lock-file" :recipe
           (:package "ace-link" :repo "abo-abo/ace-link" :fetcher
                     github :files
                     ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                      "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
                      "doc/*.texinfo" "lisp/*.el" "docs/dir"
                      "docs/*.info" "docs/*.texi" "docs/*.texinfo"
                      (:exclude ".dir-locals.el" "test.el" "tests.el"
                                "*-test.el" "*-tests.el" "LICENSE"
                                "README*" "*-pkg.el"))
                     :source "MELPA" :id ace-link :type git :protocol
                     https :inherit t :depth treeless :ref
                     "d9bd4a25a02bdfde4ea56247daf3a9ff15632ea4"))
 (acp :source "elpaca-menu-lock-file" :recipe
      (:package "acp" :fetcher github :repo "xenodium/acp.el" :files
                ("*.el" "*.el.in" "dir" "*.info" "*.texi" "*.texinfo"
                 "doc/dir" "doc/*.info" "doc/*.texi" "doc/*.texinfo"
                 "lisp/*.el" "docs/dir" "docs/*.info" "docs/*.texi"
                 "docs/*.texinfo"
                 (:exclude ".dir-locals.el" "test.el" "tests.el"
                           "*-test.el" "*-tests.el" "LICENSE"
                           "README*" "*-pkg.el"))
                :source "MELPA" :id acp :type git :protocol https
                :inherit t :depth treeless :ref
                "7d5c16ebcf2af86aa0f14ad9ae0ce45df4e8c8a5"))
 (adaptive-wrap :source "elpaca-menu-lock-file" :recipe
                (:package "adaptive-wrap" :repo
                          ("https://github.com/emacsmirror/gnu_elpa"
                           . "adaptive-wrap")
                          :tar "0.9" :host gnu :branch
                          "externals/adaptive-wrap" :files
                          ("*" (:exclude ".git")) :source "GNU ELPA"
                          :id adaptive-wrap :type git :protocol https
                          :inherit t :depth treeless :ref
                          "e929b38c12f17aa6f8d6270326301d61fbb09cab"))
 (age :source "elpaca-menu-lock-file" :recipe
      (:package "age" :fetcher github :repo "anticomputer/age.el"
                :files
                ("*.el" "*.el.in" "dir" "*.info" "*.texi" "*.texinfo"
                 "doc/dir" "doc/*.info" "doc/*.texi" "doc/*.texinfo"
                 "lisp/*.el" "docs/dir" "docs/*.info" "docs/*.texi"
                 "docs/*.texinfo"
                 (:exclude ".dir-locals.el" "test.el" "tests.el"
                           "*-test.el" "*-tests.el" "LICENSE"
                           "README*" "*-pkg.el"))
                :source "MELPA" :id age :type git :protocol https
                :inherit t :depth treeless :ref
                "e99165ef5274bc4512b8d77ba2ac208c59b5d456"))
 (agent-shell :source "elpaca-menu-lock-file" :recipe
              (:package "agent-shell" :fetcher github :repo
                        "xenodium/agent-shell" :files
                        ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                         "*.texinfo" "doc/dir" "doc/*.info"
                         "doc/*.texi" "doc/*.texinfo" "lisp/*.el"
                         "docs/dir" "docs/*.info" "docs/*.texi"
                         "docs/*.texinfo"
                         (:exclude ".dir-locals.el" "test.el"
                                   "tests.el" "*-test.el" "*-tests.el"
                                   "LICENSE" "README*" "*-pkg.el"))
                        :source "MELPA" :id agent-shell :type git
                        :protocol https :inherit t :depth treeless
                        :ref
                        "6929073c9a4b0898ac62f160e1c0779f19461df8"))
 (agent-shell-sidebar :source "elpaca-menu-lock-file" :recipe
                      (:source nil :package "agent-shell-sidebar" :id
                               agent-shell-sidebar :host nil :repo
                               "ssh://git@git.cashmere.rs/agent-shell-sidebar.git"
                               :type git :protocol https :inherit t
                               :depth treeless :ref
                               "10fee0b1463cdf210b0908c23e940a44c8d4a8e2"))
 (alert :source "elpaca-menu-lock-file" :recipe
        (:package "alert" :fetcher github :repo "jwiegley/alert"
                  :files
                  ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                   "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
                   "doc/*.texinfo" "lisp/*.el" "docs/dir"
                   "docs/*.info" "docs/*.texi" "docs/*.texinfo"
                   (:exclude ".dir-locals.el" "test.el" "tests.el"
                             "*-test.el" "*-tests.el" "LICENSE"
                             "README*" "*-pkg.el"))
                  :source "MELPA" :id alert :type git :protocol https
                  :inherit t :depth treeless :ref
                  "31fc56855289d0846e73d7ca9b84b628aeac16a0"))
 (async :source "elpaca-menu-lock-file" :recipe
        (:package "async" :repo "jwiegley/emacs-async" :fetcher github
                  :files
                  ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                   "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
                   "doc/*.texinfo" "lisp/*.el" "docs/dir"
                   "docs/*.info" "docs/*.texi" "docs/*.texinfo"
                   (:exclude ".dir-locals.el" "test.el" "tests.el"
                             "*-test.el" "*-tests.el" "LICENSE"
                             "README*" "*-pkg.el"))
                  :source "MELPA" :id async :type git :protocol https
                  :inherit t :depth treeless :ref
                  "4fdcb061a166e0d6ccc27d3829a28e04415ae825"))
 (avy :source "elpaca-menu-lock-file" :recipe
      (:package "avy" :repo "abo-abo/avy" :fetcher github :files
                ("*.el" "*.el.in" "dir" "*.info" "*.texi" "*.texinfo"
                 "doc/dir" "doc/*.info" "doc/*.texi" "doc/*.texinfo"
                 "lisp/*.el" "docs/dir" "docs/*.info" "docs/*.texi"
                 "docs/*.texinfo"
                 (:exclude ".dir-locals.el" "test.el" "tests.el"
                           "*-test.el" "*-tests.el" "LICENSE"
                           "README*" "*-pkg.el"))
                :source "MELPA" :id avy :type git :protocol https
                :inherit t :depth treeless :ref
                "933d1f36cca0f71e4acb5fac707e9ae26c536264"))
 (batppuccin :source "elpaca-menu-lock-file" :recipe
             (:package "batppuccin" :fetcher github :repo
                       "bbatsov/batppuccin-emacs" :files
                       ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                        "*.texinfo" "doc/dir" "doc/*.info"
                        "doc/*.texi" "doc/*.texinfo" "lisp/*.el"
                        "docs/dir" "docs/*.info" "docs/*.texi"
                        "docs/*.texinfo"
                        (:exclude ".dir-locals.el" "test.el"
                                  "tests.el" "*-test.el" "*-tests.el"
                                  "LICENSE" "README*" "*-pkg.el"))
                       :source "MELPA" :id batppuccin :type git
                       :protocol https :inherit t :depth treeless :ref
                       "d172cd51a139c4220cb2eb8afb7c0401ad8d866e"))
 (benchmark-init :source "elpaca-menu-lock-file" :recipe
                 (:package "benchmark-init" :fetcher github :repo
                           "dholm/benchmark-init-el" :files
                           ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                            "*.texinfo" "doc/dir" "doc/*.info"
                            "doc/*.texi" "doc/*.texinfo" "lisp/*.el"
                            "docs/dir" "docs/*.info" "docs/*.texi"
                            "docs/*.texinfo"
                            (:exclude ".dir-locals.el" "test.el"
                                      "tests.el" "*-test.el"
                                      "*-tests.el" "LICENSE" "README*"
                                      "*-pkg.el"))
                           :source "MELPA" :id benchmark-init :wait t
                           :type git :protocol https :inherit t :depth
                           treeless :ref
                           "54b9703389f25012e4cc20fe4a0d4ea253ce4820"))
 (cape :source "elpaca-menu-lock-file" :recipe
       (:package "cape" :repo "minad/cape" :fetcher github :files
                 ("*.el" "*.el.in" "dir" "*.info" "*.texi" "*.texinfo"
                  "doc/dir" "doc/*.info" "doc/*.texi" "doc/*.texinfo"
                  "lisp/*.el" "docs/dir" "docs/*.info" "docs/*.texi"
                  "docs/*.texinfo"
                  (:exclude ".dir-locals.el" "test.el" "tests.el"
                            "*-test.el" "*-tests.el" "LICENSE"
                            "README*" "*-pkg.el"))
                 :source "MELPA" :id cape :wait t :type git :protocol
                 https :inherit t :depth treeless :ref
                 "bd827d913f487d2bb3815731ac20b60419b9cb03"))
 (citre :source "elpaca-menu-lock-file" :recipe
        (:package "citre" :repo "universal-ctags/citre" :fetcher
                  github :files
                  ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                   "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
                   "doc/*.texinfo" "lisp/*.el" "docs/dir"
                   "docs/*.info" "docs/*.texi" "docs/*.texinfo"
                   (:exclude ".dir-locals.el" "test.el" "tests.el"
                             "*-test.el" "*-tests.el" "LICENSE"
                             "README*" "*-pkg.el"))
                  :source "MELPA" :id citre :type git :protocol https
                  :inherit t :depth treeless :ref
                  "be0d9c6dc9b1ac67d76fc7ed315f2369d5c3bde8"))
 (clipetty :source "elpaca-menu-lock-file" :recipe
           (:package "clipetty" :repo "spudlyo/clipetty" :fetcher
                     github :files
                     ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                      "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
                      "doc/*.texinfo" "lisp/*.el" "docs/dir"
                      "docs/*.info" "docs/*.texi" "docs/*.texinfo"
                      (:exclude ".dir-locals.el" "test.el" "tests.el"
                                "*-test.el" "*-tests.el" "LICENSE"
                                "README*" "*-pkg.el"))
                     :source "MELPA" :id clipetty :type git :protocol
                     https :inherit t :depth treeless :ref
                     "01b39044b9b65fa4ea7d3166f8b1ffab6f740362"))
 (colorful-mode :source "elpaca-menu-lock-file" :recipe
                (:package "colorful-mode" :repo
                          ("https://github.com/DevelopmentCool2449/colorful-mode"
                           . "colorful-mode")
                          :tar "1.2.5" :host gnu :files
                          ("*" (:exclude ".git")) :source "GNU ELPA"
                          :id colorful-mode :type git :protocol https
                          :inherit t :depth treeless :ref
                          "6712e9c969bfa8fc8538a0c1bd57a8ef9f974780"))
 (company :source "elpaca-menu-lock-file" :recipe
          (:package "company" :fetcher github :repo
                    "company-mode/company-mode" :files
                    (:defaults "icons"
                               ("images/small"
                                "doc/images/small/*.png"))
                    :source "MELPA" :id company :type git :protocol
                    https :inherit t :depth treeless :ref
                    "1cc907ac9e46ae4209eb5a341131787e0c678406"))
 (compat :source "elpaca-menu-lock-file" :recipe
         (:package "compat" :repo
                   ("https://github.com/emacs-compat/compat"
                    . "compat")
                   :tar "31.0.0.1" :host gnu :files
                   ("*" (:exclude ".git")) :source "GNU ELPA" :id
                   compat :type git :protocol https :inherit t :depth
                   treeless :ref
                   "ad2720457067b72859ba1247f6fdb3361b204bc6"))
 (cond-let
   :source "elpaca-menu-lock-file" :recipe
   (:package "cond-let" :fetcher github :repo "tarsius/cond-let"
             :files
             ("*.el" "*.el.in" "dir" "*.info" "*.texi" "*.texinfo"
              "doc/dir" "doc/*.info" "doc/*.texi" "doc/*.texinfo"
              "lisp/*.el" "docs/dir" "docs/*.info" "docs/*.texi"
              "docs/*.texinfo"
              (:exclude ".dir-locals.el" "test.el" "tests.el"
                        "*-test.el" "*-tests.el" "LICENSE" "README*"
                        "*-pkg.el"))
             :source "MELPA" :id cond-let :type git :protocol https
             :inherit t :depth treeless :ref
             "c48600dfab6372670225f046cace263700c78eab"))
 (dash :source "elpaca-menu-lock-file" :recipe
       (:package "dash" :fetcher github :repo "magnars/dash.el" :files
                 ("dash.el" "dash.texi") :source "MELPA" :id dash
                 :type git :protocol https :inherit t :depth treeless
                 :ref "d746dd9edcb67a108818beb0cdc78dc1cb466832"))
 (denote :source "elpaca-menu-lock-file" :recipe
         (:package "denote" :repo
                   ("https://github.com/protesilaos/denote" . "denote")
                   :tar "4.2.3" :host gnu :files
                   ("*" (:exclude ".git" "COPYING" "doclicense.texi"))
                   :source "GNU ELPA" :id denote :wait t :type git
                   :protocol https :inherit t :depth treeless :ref
                   "9ae9d0e1ea30b4fcc1700caafbd55a1ff08ad7b6"))
 (denote-agenda :source "elpaca-menu-lock-file" :recipe
                (:package "denote-agenda" :fetcher sourcehut :repo
                          "swflint/denote-agenda" :files
                          ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                           "*.texinfo" "doc/dir" "doc/*.info"
                           "doc/*.texi" "doc/*.texinfo" "lisp/*.el"
                           "docs/dir" "docs/*.info" "docs/*.texi"
                           "docs/*.texinfo"
                           (:exclude ".dir-locals.el" "test.el"
                                     "tests.el" "*-test.el"
                                     "*-tests.el" "LICENSE" "README*"
                                     "*-pkg.el"))
                          :source "MELPA" :id denote-agenda :type git
                          :protocol https :inherit t :depth treeless
                          :ref
                          "51935f6c9372f320be1b873ae4205b77490572d0"))
 (denote-journal :source "elpaca-menu-lock-file" :recipe
                 (:package "denote-journal" :repo
                           ("https://github.com/protesilaos/denote-journal"
                            . "denote-journal")
                           :tar "0.3.0" :host gnu :files
                           ("*" (:exclude ".git")) :source "GNU ELPA"
                           :id denote-journal :type git :protocol
                           https :inherit t :depth treeless :ref
                           "374224ad2b3162c1fa92bb9ecdb61f157a781c4b"))
 (denote-merge :source "elpaca-menu-lock-file" :recipe
               (:source nil :package "denote-merge" :id denote-merge
                        :host github :repo "protesilaos/denote-merge"
                        :type git :protocol https :inherit t :depth
                        treeless :ref
                        "2f8d168d37e66b5c8a3b983e211031b9abbf402e"))
 (denote-org :source "elpaca-menu-lock-file" :recipe
             (:package "denote-org" :repo
                       ("https://github.com/protesilaos/denote-org"
                        . "denote-org")
                       :tar "0.3.0" :host gnu :files
                       ("*" (:exclude ".git")) :source "GNU ELPA" :id
                       denote-org :type git :protocol https :inherit t
                       :depth treeless :ref
                       "b6b788db84fbf0c918bce6b3ce65508dd651bb4c"))
 (denote-publish :source "elpaca-menu-lock-file" :recipe
                 (:source nil :package "denote-publish" :id
                          denote-publish :repo
                          "https://github.com/vedang/denote-publish"
                          :type git :protocol https :inherit t :depth
                          treeless :ref
                          "42fa69618f650cd7e1b60a6cf020ed21ab7d90ee"))
 (denote-solo :source "elpaca-menu-lock-file" :recipe
              (:source nil :package "denote-solo" :id denote-solo
                       :host github :repo "pavlo/denote-solo" :type
                       git :protocol https :inherit t :depth treeless
                       :ref "69b25cbdecf8477e5e0a920a82f8f079209fd45e"))
 (diff-hl :source "elpaca-menu-lock-file" :recipe
          (:package "diff-hl" :fetcher github :repo "dgutov/diff-hl"
                    :files
                    ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                     "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
                     "doc/*.texinfo" "lisp/*.el" "docs/dir"
                     "docs/*.info" "docs/*.texi" "docs/*.texinfo"
                     (:exclude ".dir-locals.el" "test.el" "tests.el"
                               "*-test.el" "*-tests.el" "LICENSE"
                               "README*" "*-pkg.el"))
                    :source "MELPA" :id diff-hl :type git :protocol
                    https :inherit t :depth treeless :ref
                    "6f1df2b83d1140a2938409b35de7f4c9c7b1defd"))
 (diredfl :source "elpaca-menu-lock-file" :recipe
          (:package "diredfl" :fetcher github :repo "purcell/diredfl"
                    :files
                    ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                     "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
                     "doc/*.texinfo" "lisp/*.el" "docs/dir"
                     "docs/*.info" "docs/*.texi" "docs/*.texinfo"
                     (:exclude ".dir-locals.el" "test.el" "tests.el"
                               "*-test.el" "*-tests.el" "LICENSE"
                               "README*" "*-pkg.el"))
                    :source "MELPA" :id diredfl :type git :protocol
                    https :inherit t :depth treeless :ref
                    "fe72d2e42ee18bf6228bba9d7086de4098f18a70"))
 (dirvish :source "elpaca-menu-lock-file" :recipe
          (:package "dirvish" :fetcher github :repo
                    "latiagertrutis/dirvish" :files
                    (:defaults "extensions/*.el") :source "MELPA" :id
                    dirvish :host github :branch "main" :type git
                    :protocol https :inherit t :depth treeless :ref
                    "bf164ee21e128837ede59be03836a9900c4a41be"))
 (dotenv-mode :source "elpaca-menu-lock-file" :recipe
              (:package "dotenv-mode" :repo
                        "preetpalS/emacs-dotenv-mode" :fetcher github
                        :files
                        ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                         "*.texinfo" "doc/dir" "doc/*.info"
                         "doc/*.texi" "doc/*.texinfo" "lisp/*.el"
                         "docs/dir" "docs/*.info" "docs/*.texi"
                         "docs/*.texinfo"
                         (:exclude ".dir-locals.el" "test.el"
                                   "tests.el" "*-test.el" "*-tests.el"
                                   "LICENSE" "README*" "*-pkg.el"))
                        :source "MELPA" :id dotenv-mode :type git
                        :protocol https :inherit t :depth treeless
                        :ref
                        "e3701bf739bde44f6484eb7753deadaf691b73fb"))
 (elfeed :source "elpaca-menu-lock-file" :recipe
         (:package "elfeed" :fetcher github :repo
                   "emacs-elfeed/elfeed" :files
                   (:defaults "README.md") :source "MELPA" :id elfeed
                   :host github :branch "main" :type git :protocol
                   https :inherit t :depth treeless :ref
                   "ccfdbf753819fe1ce2f97a1317749003c001443f"))
 (elfeed-goodies :source "elpaca-menu-lock-file" :recipe
                 (:package "elfeed-goodies" :repo
                           "jeetelongname/elfeed-goodies" :fetcher
                           github :files
                           ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                            "*.texinfo" "doc/dir" "doc/*.info"
                            "doc/*.texi" "doc/*.texinfo" "lisp/*.el"
                            "docs/dir" "docs/*.info" "docs/*.texi"
                            "docs/*.texinfo"
                            (:exclude ".dir-locals.el" "test.el"
                                      "tests.el" "*-test.el"
                                      "*-tests.el" "LICENSE" "README*"
                                      "*-pkg.el"))
                           :source "MELPA" :id elfeed-goodies :type
                           git :protocol https :inherit t :depth
                           treeless :ref
                           "544ef42ead011d960a0ad1c1d34df5d222461a6b"))
 (elfeed-protocol :source "elpaca-menu-lock-file" :recipe
                  (:package "elfeed-protocol" :repo
                            "fasheng/elfeed-protocol" :fetcher github
                            :files
                            ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                             "*.texinfo" "doc/dir" "doc/*.info"
                             "doc/*.texi" "doc/*.texinfo" "lisp/*.el"
                             "docs/dir" "docs/*.info" "docs/*.texi"
                             "docs/*.texinfo"
                             (:exclude ".dir-locals.el" "test.el"
                                       "tests.el" "*-test.el"
                                       "*-tests.el" "LICENSE"
                                       "README*" "*-pkg.el"))
                            :source "MELPA" :id elfeed-protocol :host
                            github :type git :protocol https :inherit
                            t :depth treeless :ref
                            "58936590459ccc2dfd6132f69983011d15d9404a"))
 (elpaca :source
   "elpaca-menu-lock-file" :recipe
   (:source nil :package "elpaca" :id elpaca :repo
            "https://github.com/progfolio/elpaca.git" :ref
            "6530ffa73b18ccee858e7c471415ab7e0c0d8ce1" :depth 1
            :inherit ignore :files
            (:defaults "elpaca-test.el" (:exclude "extensions"))
            :build (:not elpaca-activate) :type git :protocol https))
 (elpaca-use-package :source "elpaca-menu-lock-file" :recipe
                     (:package "elpaca-use-package" :wait t :repo
                               "https://github.com/progfolio/elpaca.git"
                               :files
                               ("extensions/elpaca-use-package.el")
                               :main
                               "extensions/elpaca-use-package.el"
                               :build
                               (:not elpaca-source elpaca-build-docs)
                               :source "Elpaca extensions" :id
                               elpaca-use-package :type git :protocol
                               https :inherit t :depth treeless :ref
                               "6530ffa73b18ccee858e7c471415ab7e0c0d8ce1"))
 (embark :source "elpaca-menu-lock-file" :recipe
         (:package "embark" :repo "oantolin/embark" :fetcher github
                   :files ("embark.el" "embark-org.el" "embark.texi")
                   :source "MELPA" :id embark :wait t :type git
                   :protocol https :inherit t :depth treeless :ref
                   "87e53827cf6659dcc4ac4e54be9af34aeca44f6e"))
 (envrc :source "elpaca-menu-lock-file" :recipe
        (:package "envrc" :fetcher github :repo "purcell/envrc" :files
                  ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                   "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
                   "doc/*.texinfo" "lisp/*.el" "docs/dir"
                   "docs/*.info" "docs/*.texi" "docs/*.texinfo"
                   (:exclude ".dir-locals.el" "test.el" "tests.el"
                             "*-test.el" "*-tests.el" "LICENSE"
                             "README*" "*-pkg.el"))
                  :source "MELPA" :id envrc :type git :protocol https
                  :inherit t :depth treeless :ref
                  "e4f9fd79a612c8f81b4ba5b12ee7261fc33568f0"))
 (evil :source "elpaca-menu-lock-file" :recipe
       (:package "evil" :repo "emacs-evil/evil" :fetcher github :files
                 (:defaults "doc/build/texinfo/evil.texi"
                            (:exclude "evil-test-helpers.el"))
                 :source "MELPA" :id evil :wait t :type git :protocol
                 https :inherit t :depth treeless :ref
                 "6a3e1ddd04ac504a016590940d0af2a3361b9efd"))
 (evil-collection :source "elpaca-menu-lock-file" :recipe
                  (:package "evil-collection" :fetcher github :repo
                            "emacs-evil/evil-collection" :files
                            (:defaults "modes") :source "MELPA" :id
                            evil-collection :wait t :type git
                            :protocol https :inherit t :depth treeless
                            :ref
                            "fa8da0ebba4bbf2a84a78183420d8303179ef427"))
 (evil-ghostel :source "elpaca-menu-lock-file" :recipe
               (:package "evil-ghostel" :fetcher github :repo
                         "dakra/ghostel" :files
                         ("extensions/evil-ghostel/*.el") :source
                         "MELPA" :id evil-ghostel :host github :type
                         git :protocol https :inherit t :depth
                         treeless :ref
                         "dd72e1f4ae891345a1f76ed98c5cbd71c18e808e"))
 (evil-matchit :source "elpaca-menu-lock-file" :recipe
               (:package "evil-matchit" :fetcher github :repo
                         "redguardtoo/evil-matchit" :files
                         ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                          "*.texinfo" "doc/dir" "doc/*.info"
                          "doc/*.texi" "doc/*.texinfo" "lisp/*.el"
                          "docs/dir" "docs/*.info" "docs/*.texi"
                          "docs/*.texinfo"
                          (:exclude ".dir-locals.el" "test.el"
                                    "tests.el" "*-test.el"
                                    "*-tests.el" "LICENSE" "README*"
                                    "*-pkg.el"))
                         :source "MELPA" :id evil-matchit :type git
                         :protocol https :inherit t :depth treeless
                         :ref
                         "dd03aacd8602ffd2cd9b67d0072092f8d57d5e01"))
 (evil-mc :source "elpaca-menu-lock-file" :recipe
          (:package "evil-mc" :fetcher github :repo "gabesoft/evil-mc"
                    :files
                    ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                     "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
                     "doc/*.texinfo" "lisp/*.el" "docs/dir"
                     "docs/*.info" "docs/*.texi" "docs/*.texinfo"
                     (:exclude ".dir-locals.el" "test.el" "tests.el"
                               "*-test.el" "*-tests.el" "LICENSE"
                               "README*" "*-pkg.el"))
                    :source "MELPA" :id evil-mc :type git :protocol
                    https :inherit t :depth treeless :ref
                    "7e363dd6b0a39751e13eb76f2e9b7b13c7054a43"))
 (evil-org :source "elpaca-menu-lock-file" :recipe
           (:package "evil-org" :fetcher github :repo
                     "Somelauw/evil-org-mode" :files
                     ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                      "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
                      "doc/*.texinfo" "lisp/*.el" "docs/dir"
                      "docs/*.info" "docs/*.texi" "docs/*.texinfo"
                      (:exclude ".dir-locals.el" "test.el" "tests.el"
                                "*-test.el" "*-tests.el" "LICENSE"
                                "README*" "*-pkg.el"))
                     :source "MELPA" :id evil-org :type git :protocol
                     https :inherit t :depth treeless :ref
                     "b1f309726b1326e1a103742524ec331789f2bf94"))
 (evil-smartparens :source "elpaca-menu-lock-file" :recipe
                   (:package "evil-smartparens" :fetcher github :repo
                             "expez/evil-smartparens" :files
                             ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                              "*.texinfo" "doc/dir" "doc/*.info"
                              "doc/*.texi" "doc/*.texinfo" "lisp/*.el"
                              "docs/dir" "docs/*.info" "docs/*.texi"
                              "docs/*.texinfo"
                              (:exclude ".dir-locals.el" "test.el"
                                        "tests.el" "*-test.el"
                                        "*-tests.el" "LICENSE"
                                        "README*" "*-pkg.el"))
                             :source "MELPA" :id evil-smartparens
                             :type git :protocol https :inherit t
                             :depth treeless :ref
                             "026d4a3cfce415a4dfae1457f871b385386e61d3"))
 (evil-surround :source "elpaca-menu-lock-file" :recipe
                (:package "evil-surround" :repo
                          "emacs-evil/evil-surround" :fetcher github
                          :old-names (surround) :files
                          ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                           "*.texinfo" "doc/dir" "doc/*.info"
                           "doc/*.texi" "doc/*.texinfo" "lisp/*.el"
                           "docs/dir" "docs/*.info" "docs/*.texi"
                           "docs/*.texinfo"
                           (:exclude ".dir-locals.el" "test.el"
                                     "tests.el" "*-test.el"
                                     "*-tests.el" "LICENSE" "README*"
                                     "*-pkg.el"))
                          :source "MELPA" :id evil-surround :type git
                          :protocol https :inherit t :depth treeless
                          :ref
                          "e6548372e8359ee55e67d73ca418314086011f1a"))
 (evil-textobj-anyblock :source "elpaca-menu-lock-file" :recipe
                        (:package "evil-textobj-anyblock" :fetcher
                                  github :repo
                                  "noctuid/evil-textobj-anyblock"
                                  :files
                                  ("*.el" "*.el.in" "dir" "*.info"
                                   "*.texi" "*.texinfo" "doc/dir"
                                   "doc/*.info" "doc/*.texi"
                                   "doc/*.texinfo" "lisp/*.el"
                                   "docs/dir" "docs/*.info"
                                   "docs/*.texi" "docs/*.texinfo"
                                   (:exclude ".dir-locals.el"
                                             "test.el" "tests.el"
                                             "*-test.el" "*-tests.el"
                                             "LICENSE" "README*"
                                             "*-pkg.el"))
                                  :source "MELPA" :id
                                  evil-textobj-anyblock :type git
                                  :protocol https :inherit t :depth
                                  treeless :ref
                                  "ff00980f0634f95bf2ad9956b615a155ea8743be"))
 (f :source "elpaca-menu-lock-file" :recipe
    (:package "f" :fetcher github :repo "rejeep/f.el" :files
              ("*.el" "*.el.in" "dir" "*.info" "*.texi" "*.texinfo"
               "doc/dir" "doc/*.info" "doc/*.texi" "doc/*.texinfo"
               "lisp/*.el" "docs/dir" "docs/*.info" "docs/*.texi"
               "docs/*.texinfo"
               (:exclude ".dir-locals.el" "test.el" "tests.el"
                         "*-test.el" "*-tests.el" "LICENSE" "README*"
                         "*-pkg.el"))
              :source "MELPA" :id f :type git :protocol https :inherit
              t :depth treeless :ref
              "931b6d0667fe03e7bf1c6c282d6d8d7006143c52"))
 (flash :source "elpaca-menu-lock-file" :recipe
        (:package "flash" :fetcher github :repo "Prgebish/flash"
                  :files
                  ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                   "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
                   "doc/*.texinfo" "lisp/*.el" "docs/dir"
                   "docs/*.info" "docs/*.texi" "docs/*.texinfo"
                   (:exclude ".dir-locals.el" "test.el" "tests.el"
                             "*-test.el" "*-tests.el" "LICENSE"
                             "README*" "*-pkg.el"))
                  :source "MELPA" :id flash :host github :type git
                  :protocol https :inherit t :depth treeless :ref
                  "db3bfa84866f143a0665d1b5a48c3b30dc7b528f"))
 (general :source "elpaca-menu-lock-file" :recipe
          (:package "general" :fetcher github :repo
                    "noctuid/general.el" :files
                    ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                     "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
                     "doc/*.texinfo" "lisp/*.el" "docs/dir"
                     "docs/*.info" "docs/*.texi" "docs/*.texinfo"
                     (:exclude ".dir-locals.el" "test.el" "tests.el"
                               "*-test.el" "*-tests.el" "LICENSE"
                               "README*" "*-pkg.el"))
                    :source "MELPA" :id general :wait t :type git
                    :protocol https :inherit t :depth treeless :ref
                    "a48768f85a655fe77b5f45c2880b420da1b1b9c3"))
 (ghostel :source "elpaca-menu-lock-file" :recipe
          (:package "ghostel" :fetcher github :repo "dakra/ghostel"
                    :files
                    (:defaults "etc" "src" "vendor" "build.zig"
                               "build.zig.zon" "symbols.map")
                    :source "MELPA" :id ghostel :type git :protocol
                    https :inherit t :depth treeless :ref
                    "dd72e1f4ae891345a1f76ed98c5cbd71c18e808e"))
 (gntp :source "elpaca-menu-lock-file" :recipe
       (:package "gntp" :repo "tekai/gntp.el" :fetcher github :files
                 ("*.el" "*.el.in" "dir" "*.info" "*.texi" "*.texinfo"
                  "doc/dir" "doc/*.info" "doc/*.texi" "doc/*.texinfo"
                  "lisp/*.el" "docs/dir" "docs/*.info" "docs/*.texi"
                  "docs/*.texinfo"
                  (:exclude ".dir-locals.el" "test.el" "tests.el"
                            "*-test.el" "*-tests.el" "LICENSE"
                            "README*" "*-pkg.el"))
                 :source "MELPA" :id gntp :type git :protocol https
                 :inherit t :depth treeless :ref
                 "767571135e2c0985944017dc59b0be79af222ef5"))
 (golden-ratio :source "elpaca-menu-lock-file" :recipe
               (:package "golden-ratio" :repo "roman/golden-ratio.el"
                         :fetcher github :files
                         ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                          "*.texinfo" "doc/dir" "doc/*.info"
                          "doc/*.texi" "doc/*.texinfo" "lisp/*.el"
                          "docs/dir" "docs/*.info" "docs/*.texi"
                          "docs/*.texinfo"
                          (:exclude ".dir-locals.el" "test.el"
                                    "tests.el" "*-test.el"
                                    "*-tests.el" "LICENSE" "README*"
                                    "*-pkg.el"))
                         :source "MELPA" :id golden-ratio :type git
                         :protocol https :inherit t :depth treeless
                         :ref
                         "375c9f287dfad68829582c1e0a67d0c18119dab9"))
 (goto-chg :source "elpaca-menu-lock-file" :recipe
           (:package "goto-chg" :repo "emacs-evil/goto-chg" :fetcher
                     github :files
                     ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                      "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
                      "doc/*.texinfo" "lisp/*.el" "docs/dir"
                      "docs/*.info" "docs/*.texi" "docs/*.texinfo"
                      (:exclude ".dir-locals.el" "test.el" "tests.el"
                                "*-test.el" "*-tests.el" "LICENSE"
                                "README*" "*-pkg.el"))
                     :source "MELPA" :id goto-chg :type git :protocol
                     https :inherit t :depth treeless :ref
                     "72f556524b88e9d30dc7fc5b0dc32078c166fda7"))
 (helm :source "elpaca-menu-lock-file" :recipe
       (:package "helm" :fetcher github :repo "emacs-helm/helm" :files
                 (:defaults "emacs-helm.sh"
                            (:exclude "helm-lib.el" "helm-source.el"
                                      "helm-multi-match.el"
                                      "helm-core.el"))
                 :source "MELPA" :id helm :wait t :type git :protocol
                 https :inherit t :depth treeless :ref
                 "acff7751af0623f1bbebb1f3bf1ee4831f7f5035"))
 (helm-core :source "elpaca-menu-lock-file" :recipe
            (:package "helm-core" :repo "emacs-helm/helm" :fetcher
                      github :files
                      ("helm-core.el" "helm-lib.el" "helm-source.el"
                       "helm-multi-match.el")
                      :source "MELPA" :id helm-core :type git
                      :protocol https :inherit t :depth treeless :ref
                      "acff7751af0623f1bbebb1f3bf1ee4831f7f5035"))
 (helm-projectile :source "elpaca-menu-lock-file" :recipe
                  (:package "helm-projectile" :repo
                            "bbatsov/helm-projectile" :fetcher github
                            :files
                            ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                             "*.texinfo" "doc/dir" "doc/*.info"
                             "doc/*.texi" "doc/*.texinfo" "lisp/*.el"
                             "docs/dir" "docs/*.info" "docs/*.texi"
                             "docs/*.texinfo"
                             (:exclude ".dir-locals.el" "test.el"
                                       "tests.el" "*-test.el"
                                       "*-tests.el" "LICENSE"
                                       "README*" "*-pkg.el"))
                            :source "MELPA" :id helm-projectile :type
                            git :protocol https :inherit t :depth
                            treeless :ref
                            "4dae1d072cc2650749846cfcab1f60686471cc45"))
 (helm-xref :source "elpaca-menu-lock-file" :recipe
            (:package "helm-xref" :repo "brotzeit/helm-xref" :fetcher
                      github :files
                      ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                       "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
                       "doc/*.texinfo" "lisp/*.el" "docs/dir"
                       "docs/*.info" "docs/*.texi" "docs/*.texinfo"
                       (:exclude ".dir-locals.el" "test.el" "tests.el"
                                 "*-test.el" "*-tests.el" "LICENSE"
                                 "README*" "*-pkg.el"))
                      :source "MELPA" :id helm-xref :type git
                      :protocol https :inherit t :depth treeless :ref
                      "ea0e4ed8a9baf236e4085cbc7178241f109a53fa"))
 (hl-todo :source "elpaca-menu-lock-file" :recipe
          (:package "hl-todo" :fetcher github :repo "tarsius/hl-todo"
                    :files
                    ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                     "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
                     "doc/*.texinfo" "lisp/*.el" "docs/dir"
                     "docs/*.info" "docs/*.texi" "docs/*.texinfo"
                     (:exclude ".dir-locals.el" "test.el" "tests.el"
                               "*-test.el" "*-tests.el" "LICENSE"
                               "README*" "*-pkg.el"))
                    :source "MELPA" :id hl-todo :host github :type git
                    :protocol https :inherit t :depth treeless :ref
                    "527d545b8c2f36243194cbe4a8d0e6ac9d50e6a7"))
 (ht :source "elpaca-menu-lock-file" :recipe
     (:package "ht" :fetcher github :repo "Wilfred/ht.el" :files
               ("*.el" "*.el.in" "dir" "*.info" "*.texi" "*.texinfo"
                "doc/dir" "doc/*.info" "doc/*.texi" "doc/*.texinfo"
                "lisp/*.el" "docs/dir" "docs/*.info" "docs/*.texi"
                "docs/*.texinfo"
                (:exclude ".dir-locals.el" "test.el" "tests.el"
                          "*-test.el" "*-tests.el" "LICENSE" "README*"
                          "*-pkg.el"))
               :source "MELPA" :id ht :type git :protocol https
               :inherit t :depth treeless :ref
               "1c49aad1c820c86f7ee35bf9fff8429502f60fef"))
 (indent-guide :source "elpaca-menu-lock-file" :recipe
               (:package "indent-guide" :fetcher github :repo
                         "zk-phi/indent-guide" :files
                         ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                          "*.texinfo" "doc/dir" "doc/*.info"
                          "doc/*.texi" "doc/*.texinfo" "lisp/*.el"
                          "docs/dir" "docs/*.info" "docs/*.texi"
                          "docs/*.texinfo"
                          (:exclude ".dir-locals.el" "test.el"
                                    "tests.el" "*-test.el"
                                    "*-tests.el" "LICENSE" "README*"
                                    "*-pkg.el"))
                         :source "MELPA" :id indent-guide :type git
                         :protocol https :inherit t :depth treeless
                         :ref
                         "1332f95d6f08afee35f62621793e2622b9f86f27"))
 (inheritenv :source "elpaca-menu-lock-file" :recipe
             (:package "inheritenv" :fetcher github :repo
                       "purcell/inheritenv" :files
                       ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                        "*.texinfo" "doc/dir" "doc/*.info"
                        "doc/*.texi" "doc/*.texinfo" "lisp/*.el"
                        "docs/dir" "docs/*.info" "docs/*.texi"
                        "docs/*.texinfo"
                        (:exclude ".dir-locals.el" "test.el"
                                  "tests.el" "*-test.el" "*-tests.el"
                                  "LICENSE" "README*" "*-pkg.el"))
                       :source "MELPA" :id inheritenv :type git
                       :protocol https :inherit t :depth treeless :ref
                       "b9e67cc20c069539698a9ac54d0e6cc11e616c6f"))
 (just-mode :source "elpaca-menu-lock-file" :recipe
            (:package "just-mode" :repo "leon-barrett/just-mode.el"
                      :fetcher github :files
                      ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                       "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
                       "doc/*.texinfo" "lisp/*.el" "docs/dir"
                       "docs/*.info" "docs/*.texi" "docs/*.texinfo"
                       (:exclude ".dir-locals.el" "test.el" "tests.el"
                                 "*-test.el" "*-tests.el" "LICENSE"
                                 "README*" "*-pkg.el"))
                      :source "MELPA" :id just-mode :type git
                      :protocol https :inherit t :depth treeless :ref
                      "5513ab0350d2701a94deb8cafef57d3c369a5e9b"))
 (language-detection :source "elpaca-menu-lock-file" :recipe
                     (:package "language-detection" :fetcher github
                               :repo
                               "andreasjansson/language-detection.el"
                               :files
                               ("*.el" "*.el.in" "dir" "*.info"
                                "*.texi" "*.texinfo" "doc/dir"
                                "doc/*.info" "doc/*.texi"
                                "doc/*.texinfo" "lisp/*.el" "docs/dir"
                                "docs/*.info" "docs/*.texi"
                                "docs/*.texinfo"
                                (:exclude ".dir-locals.el" "test.el"
                                          "tests.el" "*-test.el"
                                          "*-tests.el" "LICENSE"
                                          "README*" "*-pkg.el"))
                               :source "MELPA" :id language-detection
                               :type git :protocol https :inherit t
                               :depth treeless :ref
                               "54a6ecf55304fba7d215ef38a4ec96daff2f35a4"))
 (link-hint :source "elpaca-menu-lock-file" :recipe
            (:package "link-hint" :fetcher github :repo
                      "noctuid/link-hint.el" :version-regexp
                      "none-since-rename" :files
                      ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                       "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
                       "doc/*.texinfo" "lisp/*.el" "docs/dir"
                       "docs/*.info" "docs/*.texi" "docs/*.texinfo"
                       (:exclude ".dir-locals.el" "test.el" "tests.el"
                                 "*-test.el" "*-tests.el" "LICENSE"
                                 "README*" "*-pkg.el"))
                      :source "MELPA" :id link-hint :type git
                      :protocol https :inherit t :depth treeless :ref
                      "8fda5dcb9caff5a3c49d22b82e570ac9e29af7dd"))
 (llama :source "elpaca-menu-lock-file" :recipe
        (:package "llama" :fetcher github :repo "tarsius/llama" :files
                  ("llama.el" ".dir-locals.el") :source "MELPA" :id
                  llama :type git :protocol https :inherit t :depth
                  treeless :ref
                  "4d4024048053b898a01521046e0f063ee47615b0"))
 (log4e :source "elpaca-menu-lock-file" :recipe
        (:package "log4e" :repo "aki2o/log4e" :fetcher github :files
                  ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                   "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
                   "doc/*.texinfo" "lisp/*.el" "docs/dir"
                   "docs/*.info" "docs/*.texi" "docs/*.texinfo"
                   (:exclude ".dir-locals.el" "test.el" "tests.el"
                             "*-test.el" "*-tests.el" "LICENSE"
                             "README*" "*-pkg.el"))
                  :source "MELPA" :id log4e :type git :protocol https
                  :inherit t :depth treeless :ref
                  "6d71462df9bf595d3861bfb328377346aceed422"))
 (magit :source "elpaca-menu-lock-file" :recipe
        (:package "magit" :fetcher github :repo "magit/magit" :files
                  ("lisp/magit*.el" "lisp/git-*.el" "docs/magit.texi"
                   "docs/AUTHORS.md" "LICENSE" ".dir-locals.el"
                   ("githooks" "githooks/*")
                   ("git-hooks" "git-hooks/*")
                   (:exclude "lisp/magit-section.el"))
                  :source "MELPA" :id magit :wait t :type git
                  :protocol https :inherit t :depth treeless :ref
                  "bb426845dc2c182da316d64ea19efc837b303e85"))
 (magit-delta :source "elpaca-menu-lock-file" :recipe
              (:package "magit-delta" :fetcher github :repo
                        "dandavison/magit-delta" :files
                        ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                         "*.texinfo" "doc/dir" "doc/*.info"
                         "doc/*.texi" "doc/*.texinfo" "lisp/*.el"
                         "docs/dir" "docs/*.info" "docs/*.texi"
                         "docs/*.texinfo"
                         (:exclude ".dir-locals.el" "test.el"
                                   "tests.el" "*-test.el" "*-tests.el"
                                   "LICENSE" "README*" "*-pkg.el"))
                        :source "MELPA" :id magit-delta :type git
                        :protocol https :inherit t :depth treeless
                        :ref
                        "5fc7dbddcfacfe46d3fd876172ad02a9ab6ac616"))
 (magit-section :source "elpaca-menu-lock-file" :recipe
                (:package "magit-section" :fetcher github :repo
                          "magit/magit" :files
                          ("lisp/magit-section.el"
                           "docs/magit-section.texi"
                           "magit-section-pkg.el")
                          :source "MELPA" :id magit-section :type git
                          :protocol https :inherit t :depth treeless
                          :ref
                          "bb426845dc2c182da316d64ea19efc837b303e85"))
 (markdown-mode :source "elpaca-menu-lock-file" :recipe
                (:package "markdown-mode" :fetcher github :repo
                          "jrblevin/markdown-mode" :files
                          ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                           "*.texinfo" "doc/dir" "doc/*.info"
                           "doc/*.texi" "doc/*.texinfo" "lisp/*.el"
                           "docs/dir" "docs/*.info" "docs/*.texi"
                           "docs/*.texinfo"
                           (:exclude ".dir-locals.el" "test.el"
                                     "tests.el" "*-test.el"
                                     "*-tests.el" "LICENSE" "README*"
                                     "*-pkg.el"))
                          :source "MELPA" :id markdown-mode :type git
                          :protocol https :inherit t :depth treeless
                          :ref
                          "f441e8bc9951e73b12c61e9198658488dd8e86e1"))
 (mode-line-maker :source "elpaca-menu-lock-file" :recipe
                  (:package "mode-line-maker" :repo
                            "rougier/mode-line-maker" :tar nil :host
                            github :files ("*" (:exclude ".git"))
                            :source "GNU ELPA" :id mode-line-maker
                            :type git :protocol https :inherit t
                            :depth treeless :ref
                            "dc0bd20750f34340448ba1c7be4ed2b62af0f78c"))
 (mu4e-alert :source "elpaca-menu-lock-file" :recipe
             (:package "mu4e-alert" :fetcher github :repo
                       "xzz53/mu4e-alert" :files
                       ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                        "*.texinfo" "doc/dir" "doc/*.info"
                        "doc/*.texi" "doc/*.texinfo" "lisp/*.el"
                        "docs/dir" "docs/*.info" "docs/*.texi"
                        "docs/*.texinfo"
                        (:exclude ".dir-locals.el" "test.el"
                                  "tests.el" "*-test.el" "*-tests.el"
                                  "LICENSE" "README*" "*-pkg.el"))
                       :source "MELPA" :id mu4e-alert :type git
                       :protocol https :inherit t :depth treeless :ref
                       "9f20f30b15a5f5cc43fe448684fe1d4b981639aa"))
 (nerd-icons :source "elpaca-menu-lock-file" :recipe
             (:package "nerd-icons" :repo
                       "rainstormstudio/nerd-icons.el" :fetcher github
                       :files (:defaults "data") :source "MELPA" :id
                       nerd-icons :type git :protocol https :inherit t
                       :depth treeless :ref
                       "1e75075e323dedaf9f2fd5837082c60a2d0dfae3"))
 (nerd-icons-dired :source "elpaca-menu-lock-file" :recipe
                   (:package "nerd-icons-dired" :repo
                             "rainstormstudio/nerd-icons-dired"
                             :fetcher github :files
                             ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                              "*.texinfo" "doc/dir" "doc/*.info"
                              "doc/*.texi" "doc/*.texinfo" "lisp/*.el"
                              "docs/dir" "docs/*.info" "docs/*.texi"
                              "docs/*.texinfo"
                              (:exclude ".dir-locals.el" "test.el"
                                        "tests.el" "*-test.el"
                                        "*-tests.el" "LICENSE"
                                        "README*" "*-pkg.el"))
                             :source "MELPA" :id nerd-icons-dired
                             :type git :protocol https :inherit t
                             :depth treeless :ref
                             "104acd8879528b8115589f35f1bbcbe231ad732f"))
 (nerd-icons-ibuffer :source "elpaca-menu-lock-file" :recipe
                     (:package "nerd-icons-ibuffer" :repo
                               "seagle0128/nerd-icons-ibuffer"
                               :fetcher github :files
                               ("*.el" "*.el.in" "dir" "*.info"
                                "*.texi" "*.texinfo" "doc/dir"
                                "doc/*.info" "doc/*.texi"
                                "doc/*.texinfo" "lisp/*.el" "docs/dir"
                                "docs/*.info" "docs/*.texi"
                                "docs/*.texinfo"
                                (:exclude ".dir-locals.el" "test.el"
                                          "tests.el" "*-test.el"
                                          "*-tests.el" "LICENSE"
                                          "README*" "*-pkg.el"))
                               :source "MELPA" :id nerd-icons-ibuffer
                               :type git :protocol https :inherit t
                               :depth treeless :ref
                               "22dcbeea8c7677c83c8464c34247cf968250ee18"))
 (nix-ts-mode :source "elpaca-menu-lock-file" :recipe
              (:package "nix-ts-mode" :fetcher github :repo
                        "nix-community/nix-ts-mode" :files
                        ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                         "*.texinfo" "doc/dir" "doc/*.info"
                         "doc/*.texi" "doc/*.texinfo" "lisp/*.el"
                         "docs/dir" "docs/*.info" "docs/*.texi"
                         "docs/*.texinfo"
                         (:exclude ".dir-locals.el" "test.el"
                                   "tests.el" "*-test.el" "*-tests.el"
                                   "LICENSE" "README*" "*-pkg.el"))
                        :source "MELPA" :id nix-ts-mode :type git
                        :protocol https :inherit t :depth treeless
                        :ref
                        "09c89886a22b8e37ac0de9210ff5b2b79c520fd7"))
 (ob-async :source "elpaca-menu-lock-file" :recipe
           (:package "ob-async" :repo "astahlman/ob-async" :fetcher
                     github :files
                     ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                      "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
                      "doc/*.texinfo" "lisp/*.el" "docs/dir"
                      "docs/*.info" "docs/*.texi" "docs/*.texinfo"
                      (:exclude ".dir-locals.el" "test.el" "tests.el"
                                "*-test.el" "*-tests.el" "LICENSE"
                                "README*" "*-pkg.el"))
                     :source "MELPA" :id ob-async :type git :protocol
                     https :inherit t :depth treeless :ref
                     "9aac486073f5c356ada20e716571be33a350a982"))
 (olivetti :source "elpaca-menu-lock-file" :recipe
           (:package "olivetti" :fetcher github :repo "rnkn/olivetti"
                     :files
                     ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                      "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
                      "doc/*.texinfo" "lisp/*.el" "docs/dir"
                      "docs/*.info" "docs/*.texi" "docs/*.texinfo"
                      (:exclude ".dir-locals.el" "test.el" "tests.el"
                                "*-test.el" "*-tests.el" "LICENSE"
                                "README*" "*-pkg.el"))
                     :source "MELPA" :id olivetti :type git :protocol
                     https :inherit t :depth treeless :ref
                     "d2ccae56b442d9c5b06dd2481057abbd7eb82551"))
 (org :source "elpaca-menu-lock-file" :recipe
      (:package "org" :host github :repo "emacsmirror/org" :autoloads
                "org-loaddefs.el" :depth nil :build
                ((:not elpaca-build-autoloads)
                 (:before elpaca-build-link elpaca-menu-org--build))
                :files
                (:defaults ("etc/styles/" "etc/styles/*" "doc/*.texi"))
                :source "Org" :id org :ref
                "0d02d72627428dddf21ec66b1eb87e46c2849ded" :wait t
                :type git :protocol https :inherit t))
 (org-appear :source "elpaca-menu-lock-file" :recipe
             (:package "org-appear" :fetcher github :repo
                       "awth13/org-appear" :files
                       ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                        "*.texinfo" "doc/dir" "doc/*.info"
                        "doc/*.texi" "doc/*.texinfo" "lisp/*.el"
                        "docs/dir" "docs/*.info" "docs/*.texi"
                        "docs/*.texinfo"
                        (:exclude ".dir-locals.el" "test.el"
                                  "tests.el" "*-test.el" "*-tests.el"
                                  "LICENSE" "README*" "*-pkg.el"))
                       :source "MELPA" :id org-appear :type git
                       :protocol https :inherit t :depth treeless :ref
                       "77d23efec5f5c25fc0798364d2b51a3ce3d8d518"))
 (org-auto-tangle :source "elpaca-menu-lock-file" :recipe
                  (:package "org-auto-tangle" :repo
                            "yilkalargaw/org-auto-tangle" :fetcher
                            github :files
                            ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                             "*.texinfo" "doc/dir" "doc/*.info"
                             "doc/*.texi" "doc/*.texinfo" "lisp/*.el"
                             "docs/dir" "docs/*.info" "docs/*.texi"
                             "docs/*.texinfo"
                             (:exclude ".dir-locals.el" "test.el"
                                       "tests.el" "*-test.el"
                                       "*-tests.el" "LICENSE"
                                       "README*" "*-pkg.el"))
                            :source "MELPA" :id org-auto-tangle :type
                            git :protocol https :inherit t :depth
                            treeless :ref
                            "b4e7abc019179df473ecddf0af80561ddad8fc58"))
 (org-cliplink :source "elpaca-menu-lock-file" :recipe
               (:package "org-cliplink" :repo "rexim/org-cliplink"
                         :fetcher github :files
                         ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                          "*.texinfo" "doc/dir" "doc/*.info"
                          "doc/*.texi" "doc/*.texinfo" "lisp/*.el"
                          "docs/dir" "docs/*.info" "docs/*.texi"
                          "docs/*.texinfo"
                          (:exclude ".dir-locals.el" "test.el"
                                    "tests.el" "*-test.el"
                                    "*-tests.el" "LICENSE" "README*"
                                    "*-pkg.el"))
                         :source "MELPA" :id org-cliplink :type git
                         :protocol https :inherit t :depth treeless
                         :ref
                         "13e0940b65d22bec34e2de4bc8cba1412a7abfbc"))
 (org-contrib :source "elpaca-menu-lock-file" :recipe
              (:package "org-contrib" :host github :repo
                        "emacsmirror/org-contrib" :files (:defaults)
                        :source "Org" :id org-contrib :wait t :type
                        git :protocol https :inherit t :depth treeless
                        :ref
                        "82f94c5612c20286d234613f0ce0d92eac2c0845"))
 (org-download :source "elpaca-menu-lock-file" :recipe
               (:package "org-download" :repo "abo-abo/org-download"
                         :fetcher github :files
                         ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                          "*.texinfo" "doc/dir" "doc/*.info"
                          "doc/*.texi" "doc/*.texinfo" "lisp/*.el"
                          "docs/dir" "docs/*.info" "docs/*.texi"
                          "docs/*.texinfo"
                          (:exclude ".dir-locals.el" "test.el"
                                    "tests.el" "*-test.el"
                                    "*-tests.el" "LICENSE" "README*"
                                    "*-pkg.el"))
                         :source "MELPA" :id org-download :type git
                         :protocol https :inherit t :depth treeless
                         :ref
                         "c8be2611786d1d8d666b7b4f73582de1093f25ac"))
 (org-ql :source "elpaca-menu-lock-file" :recipe
         (:package "org-ql" :fetcher github :repo "alphapapa/org-ql"
                   :files (:defaults (:exclude "helm-org-ql.el"))
                   :source "MELPA" :id org-ql :type git :protocol
                   https :inherit t :depth treeless :ref
                   "4b8330a683c43bb4a2c64ccce8cd5a90c8b174ca"))
 (org-super-agenda :source "elpaca-menu-lock-file" :recipe
                   (:package "org-super-agenda" :fetcher github :repo
                             "alphapapa/org-super-agenda" :files
                             ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                              "*.texinfo" "doc/dir" "doc/*.info"
                              "doc/*.texi" "doc/*.texinfo" "lisp/*.el"
                              "docs/dir" "docs/*.info" "docs/*.texi"
                              "docs/*.texinfo"
                              (:exclude ".dir-locals.el" "test.el"
                                        "tests.el" "*-test.el"
                                        "*-tests.el" "LICENSE"
                                        "README*" "*-pkg.el"))
                             :source "MELPA" :id org-super-agenda
                             :type git :protocol https :inherit t
                             :depth treeless :ref
                             "fb20ad9c8a9705aa05d40751682beae2d094e0fe"))
 (ov :source "elpaca-menu-lock-file" :recipe
     (:package "ov" :fetcher github :repo "emacsorphanage/ov" :files
               ("*.el" "*.el.in" "dir" "*.info" "*.texi" "*.texinfo"
                "doc/dir" "doc/*.info" "doc/*.texi" "doc/*.texinfo"
                "lisp/*.el" "docs/dir" "docs/*.info" "docs/*.texi"
                "docs/*.texinfo"
                (:exclude ".dir-locals.el" "test.el" "tests.el"
                          "*-test.el" "*-tests.el" "LICENSE" "README*"
                          "*-pkg.el"))
               :source "MELPA" :id ov :type git :protocol https
               :inherit t :depth treeless :ref
               "e2971ad986b6ac441e9849031d34c56c980cf40b"))
 (ox-gfm :source "elpaca-menu-lock-file" :recipe
         (:package "ox-gfm" :fetcher github :repo "larstvei/ox-gfm"
                   :files
                   ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                    "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
                    "doc/*.texinfo" "lisp/*.el" "docs/dir"
                    "docs/*.info" "docs/*.texi" "docs/*.texinfo"
                    (:exclude ".dir-locals.el" "test.el" "tests.el"
                              "*-test.el" "*-tests.el" "LICENSE"
                              "README*" "*-pkg.el"))
                   :source "MELPA" :id ox-gfm :type git :protocol
                   https :inherit t :depth treeless :ref
                   "4f774f13d34b3db9ea4ddb0b1edc070b1526ccbb"))
 (ox-json :source "elpaca-menu-lock-file" :recipe
          (:package "ox-json" :fetcher github :repo "jlumpe/ox-json"
                    :files
                    ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                     "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
                     "doc/*.texinfo" "lisp/*.el" "docs/dir"
                     "docs/*.info" "docs/*.texi" "docs/*.texinfo"
                     (:exclude ".dir-locals.el" "test.el" "tests.el"
                               "*-test.el" "*-tests.el" "LICENSE"
                               "README*" "*-pkg.el"))
                    :source "MELPA" :id ox-json :type git :protocol
                    https :inherit t :depth treeless :ref
                    "0f7c63b9bbbf6c8b2547e46adc7f34289869105f"))
 (ox-pandoc :source "elpaca-menu-lock-file" :recipe
            (:package "ox-pandoc" :repo "emacsorphanage/ox-pandoc"
                      :fetcher github :files
                      ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                       "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
                       "doc/*.texinfo" "lisp/*.el" "docs/dir"
                       "docs/*.info" "docs/*.texi" "docs/*.texinfo"
                       (:exclude ".dir-locals.el" "test.el" "tests.el"
                                 "*-test.el" "*-tests.el" "LICENSE"
                                 "README*" "*-pkg.el"))
                      :source "MELPA" :id ox-pandoc :wait t :type git
                      :protocol https :inherit t :depth treeless :ref
                      "1caeb56a4be26597319e7288edbc2cabada151b4"))
 (ox-typst :source "elpaca-menu-lock-file" :recipe
           (:package "ox-typst" :fetcher github :repo
                     "jmpunkt/ox-typst" :files
                     ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                      "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
                      "doc/*.texinfo" "lisp/*.el" "docs/dir"
                      "docs/*.info" "docs/*.texi" "docs/*.texinfo"
                      (:exclude ".dir-locals.el" "test.el" "tests.el"
                                "*-test.el" "*-tests.el" "LICENSE"
                                "README*" "*-pkg.el"))
                     :source "MELPA" :id ox-typst :host github :type
                     git :protocol https :inherit t :depth treeless
                     :ref "3e499609a201405a6064144792dab14e3cc19b93"))
 (pass :source "elpaca-menu-lock-file" :recipe
       (:package "pass" :fetcher github :repo "NicolasPetton/pass"
                 :files
                 ("*.el" "*.el.in" "dir" "*.info" "*.texi" "*.texinfo"
                  "doc/dir" "doc/*.info" "doc/*.texi" "doc/*.texinfo"
                  "lisp/*.el" "docs/dir" "docs/*.info" "docs/*.texi"
                  "docs/*.texinfo"
                  (:exclude ".dir-locals.el" "test.el" "tests.el"
                            "*-test.el" "*-tests.el" "LICENSE"
                            "README*" "*-pkg.el"))
                 :source "MELPA" :id pass :type git :protocol https
                 :inherit t :depth treeless :ref
                 "143456809fd2dbece9f241f4361085e1de0b0e75"))
 (passage :source "elpaca-menu-lock-file" :recipe
          (:source nil :package "passage" :id passage :host github
                   :repo "anticomputer/passage.el" :type git :protocol
                   https :inherit t :depth treeless :ref
                   "c00e020dba93ff272c4066d4f93f0f1b05528ef6"))
 (password-store :source "elpaca-menu-lock-file" :recipe
                 (:package "password-store" :fetcher github :repo
                           "zx2c4/password-store" :files
                           ("contrib/emacs/*.el") :source "MELPA" :id
                           password-store :type git :protocol https
                           :inherit t :depth treeless :ref
                           "3ca13cd8882cae4083c1c478858adbf2e82dd037"))
 (password-store-otp :source "elpaca-menu-lock-file" :recipe
                     (:package "password-store-otp" :repo
                               "volrath/password-store-otp.el"
                               :fetcher github :files
                               ("*.el" "*.el.in" "dir" "*.info"
                                "*.texi" "*.texinfo" "doc/dir"
                                "doc/*.info" "doc/*.texi"
                                "doc/*.texinfo" "lisp/*.el" "docs/dir"
                                "docs/*.info" "docs/*.texi"
                                "docs/*.texinfo"
                                (:exclude ".dir-locals.el" "test.el"
                                          "tests.el" "*-test.el"
                                          "*-tests.el" "LICENSE"
                                          "README*" "*-pkg.el"))
                               :source "MELPA" :id password-store-otp
                               :type git :protocol https :inherit t
                               :depth treeless :ref
                               "be3a00a981921ed1b2f78012944dc25eb5a0beca"))
 (persp-mode :source "elpaca-menu-lock-file" :recipe
             (:package "persp-mode" :repo "Bad-ptr/persp-mode.el"
                       :fetcher github :files
                       ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                        "*.texinfo" "doc/dir" "doc/*.info"
                        "doc/*.texi" "doc/*.texinfo" "lisp/*.el"
                        "docs/dir" "docs/*.info" "docs/*.texi"
                        "docs/*.texinfo"
                        (:exclude ".dir-locals.el" "test.el"
                                  "tests.el" "*-test.el" "*-tests.el"
                                  "LICENSE" "README*" "*-pkg.el"))
                       :source "MELPA" :id persp-mode :type git
                       :protocol https :inherit t :depth treeless :ref
                       "fab4bf76927445d2e431f06e74572acba81f47d5"))
 (popwin :source "elpaca-menu-lock-file" :recipe
         (:package "popwin" :fetcher github :repo
                   "emacsorphanage/popwin" :files
                   ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                    "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
                    "doc/*.texinfo" "lisp/*.el" "docs/dir"
                    "docs/*.info" "docs/*.texi" "docs/*.texinfo"
                    (:exclude ".dir-locals.el" "test.el" "tests.el"
                              "*-test.el" "*-tests.el" "LICENSE"
                              "README*" "*-pkg.el"))
                   :source "MELPA" :id popwin :type git :protocol
                   https :inherit t :depth treeless :ref
                   "b67254bef763ffa5ab781460bc47d6adf6f87127"))
 (posframe :source "elpaca-menu-lock-file" :recipe
           (:package "posframe" :fetcher github :repo
                     "tumashu/posframe" :files
                     ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                      "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
                      "doc/*.texinfo" "lisp/*.el" "docs/dir"
                      "docs/*.info" "docs/*.texi" "docs/*.texinfo"
                      (:exclude ".dir-locals.el" "test.el" "tests.el"
                                "*-test.el" "*-tests.el" "LICENSE"
                                "README*" "*-pkg.el"))
                     :source "MELPA" :id posframe :type git :protocol
                     https :inherit t :depth treeless :ref
                     "74c8c56131ed866db47ae4191364b72dd4852456"))
 (powerline :source "elpaca-menu-lock-file" :recipe
            (:package "powerline" :fetcher github :repo
                      "milkypostman/powerline" :files
                      ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                       "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
                       "doc/*.texinfo" "lisp/*.el" "docs/dir"
                       "docs/*.info" "docs/*.texi" "docs/*.texinfo"
                       (:exclude ".dir-locals.el" "test.el" "tests.el"
                                 "*-test.el" "*-tests.el" "LICENSE"
                                 "README*" "*-pkg.el"))
                      :source "MELPA" :id powerline :type git
                      :protocol https :inherit t :depth treeless :ref
                      "c35c35bdf5ce2d992882c1f06f0f078058870d4a"))
 (projectile :source "elpaca-menu-lock-file" :recipe
             (:package "projectile" :fetcher github :repo
                       "bbatsov/projectile" :files
                       ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                        "*.texinfo" "doc/dir" "doc/*.info"
                        "doc/*.texi" "doc/*.texinfo" "lisp/*.el"
                        "docs/dir" "docs/*.info" "docs/*.texi"
                        "docs/*.texinfo"
                        (:exclude ".dir-locals.el" "test.el"
                                  "tests.el" "*-test.el" "*-tests.el"
                                  "LICENSE" "README*" "*-pkg.el"))
                       :source "MELPA" :id projectile :wait t :type
                       git :protocol https :inherit t :depth treeless
                       :ref "10fa39917aa3a5c7f64aae31da49b4dfd9f6eb55"))
 (pulsar :source "elpaca-menu-lock-file" :recipe
         (:package "pulsar" :repo
                   ("https://github.com/protesilaos/pulsar" . "pulsar")
                   :tar "1.3.4" :host gnu :files
                   ("*" (:exclude ".git" "COPYING" "doclicense.texi"))
                   :source "GNU ELPA" :id pulsar :type git :protocol
                   https :inherit t :depth treeless :ref
                   "1849c0720c3fe5eb92f800b20351b58bce8804b6"))
 (pyvenv :source "elpaca-menu-lock-file" :recipe
         (:package "pyvenv" :fetcher github :repo
                   "jorgenschaefer/pyvenv" :files
                   ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                    "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
                    "doc/*.texinfo" "lisp/*.el" "docs/dir"
                    "docs/*.info" "docs/*.texi" "docs/*.texinfo"
                    (:exclude ".dir-locals.el" "test.el" "tests.el"
                              "*-test.el" "*-tests.el" "LICENSE"
                              "README*" "*-pkg.el"))
                   :source "MELPA" :id pyvenv :type git :protocol
                   https :inherit t :depth treeless :ref
                   "31ea715f2164dd611e7fc77b26390ef3ca93509b"))
 (rainbow-delimiters :source "elpaca-menu-lock-file" :recipe
                     (:package "rainbow-delimiters" :fetcher github
                               :repo "Fanael/rainbow-delimiters"
                               :files
                               ("*.el" "*.el.in" "dir" "*.info"
                                "*.texi" "*.texinfo" "doc/dir"
                                "doc/*.info" "doc/*.texi"
                                "doc/*.texinfo" "lisp/*.el" "docs/dir"
                                "docs/*.info" "docs/*.texi"
                                "docs/*.texinfo"
                                (:exclude ".dir-locals.el" "test.el"
                                          "tests.el" "*-test.el"
                                          "*-tests.el" "LICENSE"
                                          "README*" "*-pkg.el"))
                               :source "MELPA" :id rainbow-delimiters
                               :type git :protocol https :inherit t
                               :depth treeless :ref
                               "f40ece58df8b2f0fb6c8576b527755a552a5e763"))
 (s :source "elpaca-menu-lock-file" :recipe
    (:package "s" :fetcher github :repo "magnars/s.el" :files
              ("*.el" "*.el.in" "dir" "*.info" "*.texi" "*.texinfo"
               "doc/dir" "doc/*.info" "doc/*.texi" "doc/*.texinfo"
               "lisp/*.el" "docs/dir" "docs/*.info" "docs/*.texi"
               "docs/*.texinfo"
               (:exclude ".dir-locals.el" "test.el" "tests.el"
                         "*-test.el" "*-tests.el" "LICENSE" "README*"
                         "*-pkg.el"))
              :source "MELPA" :id s :type git :protocol https :inherit
              t :depth treeless :ref
              "d7c04b84d03481a1ed62ee13dbe595224ccbe57c"))
 (shell-maker :source "elpaca-menu-lock-file" :recipe
              (:package "shell-maker" :fetcher github :repo
                        "xenodium/shell-maker" :files
                        ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                         "*.texinfo" "doc/dir" "doc/*.info"
                         "doc/*.texi" "doc/*.texinfo" "lisp/*.el"
                         "docs/dir" "docs/*.info" "docs/*.texi"
                         "docs/*.texinfo"
                         (:exclude ".dir-locals.el" "test.el"
                                   "tests.el" "*-test.el" "*-tests.el"
                                   "LICENSE" "README*" "*-pkg.el"))
                        :source "MELPA" :id shell-maker :type git
                        :protocol https :inherit t :depth treeless
                        :ref
                        "e7c11e029f3fb54f2c04803d3833e0ccaff4ed3e"))
 (shr-tag-pre-highlight :source "elpaca-menu-lock-file" :recipe
                        (:package "shr-tag-pre-highlight" :fetcher
                                  github :repo
                                  "xuchunyang/shr-tag-pre-highlight.el"
                                  :files
                                  ("*.el" "*.el.in" "dir" "*.info"
                                   "*.texi" "*.texinfo" "doc/dir"
                                   "doc/*.info" "doc/*.texi"
                                   "doc/*.texinfo" "lisp/*.el"
                                   "docs/dir" "docs/*.info"
                                   "docs/*.texi" "docs/*.texinfo"
                                   (:exclude ".dir-locals.el"
                                             "test.el" "tests.el"
                                             "*-test.el" "*-tests.el"
                                             "LICENSE" "README*"
                                             "*-pkg.el"))
                                  :source "MELPA" :id
                                  shr-tag-pre-highlight :host github
                                  :type git :protocol https :inherit t
                                  :depth treeless :ref
                                  "02a93d48f030d71eba460bd09d091baedcad6626"))
 (shrface :source "elpaca-menu-lock-file" :recipe
          (:package "shrface" :fetcher github :repo
                    "chenyanming/shrface" :files
                    ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                     "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
                     "doc/*.texinfo" "lisp/*.el" "docs/dir"
                     "docs/*.info" "docs/*.texi" "docs/*.texinfo"
                     (:exclude ".dir-locals.el" "test.el" "tests.el"
                               "*-test.el" "*-tests.el" "LICENSE"
                               "README*" "*-pkg.el"))
                    :source "MELPA" :id shrface :type git :protocol
                    https :inherit t :depth treeless :ref
                    "6dad83387dcdd7b018c34c9ec6799926e54e66ec"))
 (smartparens :source "elpaca-menu-lock-file" :recipe
              (:package "smartparens" :fetcher github :repo
                        "Fuco1/smartparens" :files
                        ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                         "*.texinfo" "doc/dir" "doc/*.info"
                         "doc/*.texi" "doc/*.texinfo" "lisp/*.el"
                         "docs/dir" "docs/*.info" "docs/*.texi"
                         "docs/*.texinfo"
                         (:exclude ".dir-locals.el" "test.el"
                                   "tests.el" "*-test.el" "*-tests.el"
                                   "LICENSE" "README*" "*-pkg.el"))
                        :source "MELPA" :id smartparens :type git
                        :protocol https :inherit t :depth treeless
                        :ref
                        "82d2cf084a19b0c2c3812e0550721f8a61996056"))
 (sops :source "elpaca-menu-lock-file" :recipe
       (:package "sops" :fetcher github :repo "djgoku/sops" :files
                 ("*.el" "*.el.in" "dir" "*.info" "*.texi" "*.texinfo"
                  "doc/dir" "doc/*.info" "doc/*.texi" "doc/*.texinfo"
                  "lisp/*.el" "docs/dir" "docs/*.info" "docs/*.texi"
                  "docs/*.texinfo"
                  (:exclude ".dir-locals.el" "test.el" "tests.el"
                            "*-test.el" "*-tests.el" "LICENSE"
                            "README*" "*-pkg.el"))
                 :source "MELPA" :id sops :type git :host github
                 :protocol https :inherit t :depth treeless :ref
                 "95b2178a71dcbf3e69729c52cba2bc23171e059d"))
 (textui :source "elpaca-menu-lock-file" :recipe
         (:source nil :package "textui" :id textui :host github :repo
                  "yibie/textui" :files ("*.el") :type git :protocol
                  https :inherit t :depth treeless :ref
                  "f6b3a06b95d80e2a2122d38c13d0df94bdf4df85"))
 (tldr :source "elpaca-menu-lock-file" :recipe
       (:package "tldr" :fetcher github :repo "kuanyui/tldr.el" :files
                 ("*.el" "*.el.in" "dir" "*.info" "*.texi" "*.texinfo"
                  "doc/dir" "doc/*.info" "doc/*.texi" "doc/*.texinfo"
                  "lisp/*.el" "docs/dir" "docs/*.info" "docs/*.texi"
                  "docs/*.texinfo"
                  (:exclude ".dir-locals.el" "test.el" "tests.el"
                            "*-test.el" "*-tests.el" "LICENSE"
                            "README*" "*-pkg.el"))
                 :source "MELPA" :id tldr :type git :protocol https
                 :inherit t :depth treeless :ref
                 "1b09d2032491d3904bd7ee9bf5ba7c7503db6593"))
 (tmr :source "elpaca-menu-lock-file" :recipe
      (:package "tmr" :repo "protesilaos/tmr" :tar "1.3.0" :host
                github :files
                ("*"
                 (:exclude ".git" "COPYING" "doclicense.texi"
                           "Makefile"))
                :source "GNU ELPA" :id tmr :type git :protocol https
                :inherit t :depth treeless :ref
                "de456e7ea5bb2ace79349f17a81f9557b610f6e0"))
 (transient :source "elpaca-menu-lock-file" :recipe
            (:package "transient" :fetcher github :repo
                      "magit/transient" :files
                      ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                       "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
                       "doc/*.texinfo" "lisp/*.el" "docs/dir"
                       "docs/*.info" "docs/*.texi" "docs/*.texinfo"
                       (:exclude ".dir-locals.el" "test.el" "tests.el"
                                 "*-test.el" "*-tests.el" "LICENSE"
                                 "README*" "*-pkg.el"))
                      :source "MELPA" :id transient :wait t :type git
                      :protocol https :inherit t :depth treeless :ref
                      "416bddb37eda2f838f1e08dddde208dae271cc39"))
 (ts :source "elpaca-menu-lock-file" :recipe
     (:package "ts" :fetcher github :repo "alphapapa/ts.el" :files
               ("*.el" "*.el.in" "dir" "*.info" "*.texi" "*.texinfo"
                "doc/dir" "doc/*.info" "doc/*.texi" "doc/*.texinfo"
                "lisp/*.el" "docs/dir" "docs/*.info" "docs/*.texi"
                "docs/*.texinfo"
                (:exclude ".dir-locals.el" "test.el" "tests.el"
                          "*-test.el" "*-tests.el" "LICENSE" "README*"
                          "*-pkg.el"))
               :source "MELPA" :id ts :type git :protocol https
               :inherit t :depth treeless :ref
               "552936017cfdec89f7fc20c254ae6b37c3f22c5b"))
 (typst-ts-mode :source "elpaca-menu-lock-file" :recipe
                (:package "typst-ts-mode" :repo
                          ("https://codeberg.org/meow_king/typst-ts-mode"
                           . "typst-ts-mode")
                          :tar "0.12.2" :host nongnu :files
                          ("*" (:exclude ".git")) :source
                          "NonGNU ELPA" :id typst-ts-mode :type git
                          :protocol https :inherit t :depth treeless
                          :ref
                          "155bb36cff3afe701a0f6b57bd3fe5c9effaa314"))
 (vui :source "elpaca-menu-lock-file" :recipe
      (:package "vui" :fetcher github :repo "d12frosted/vui.el" :files
                ("*.el") :source "MELPA" :id vui :host github :type
                git :protocol https :inherit t :depth treeless :ref
                "85629098045154680e16f9e8a7a3e0aeffe7a0ae"))
 (wfnames :source "elpaca-menu-lock-file" :recipe
          (:package "wfnames" :fetcher github :repo
                    "thierryvolpiatto/wfnames" :files
                    ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                     "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
                     "doc/*.texinfo" "lisp/*.el" "docs/dir"
                     "docs/*.info" "docs/*.texi" "docs/*.texinfo"
                     (:exclude ".dir-locals.el" "test.el" "tests.el"
                               "*-test.el" "*-tests.el" "LICENSE"
                               "README*" "*-pkg.el"))
                    :source "MELPA" :id wfnames :type git :protocol
                    https :inherit t :depth treeless :ref
                    "d8839fa42a24f7c781cd2d8c3f40eda31faa19be"))
 (wgrep :source "elpaca-menu-lock-file" :recipe
        (:package "wgrep" :fetcher github :repo
                  "mhayashi1120/Emacs-wgrep" :files ("wgrep.el")
                  :source "MELPA" :id wgrep :type git :protocol https
                  :inherit t :depth treeless :ref
                  "49f09ab9b706d2312cab1199e1eeb1bcd3f27f6f"))
 (wgrep-helm :source "elpaca-menu-lock-file" :recipe
             (:package "wgrep-helm" :fetcher github :repo
                       "mhayashi1120/Emacs-wgrep" :files
                       ("wgrep-helm.el") :version-regexp "helm-%v"
                       :source "MELPA" :id wgrep-helm :type git
                       :protocol https :inherit t :depth treeless :ref
                       "49f09ab9b706d2312cab1199e1eeb1bcd3f27f6f"))
 (which-key :source "elpaca-menu-lock-file" :recipe
            (:package "which-key" :repo "justbur/emacs-which-key"
                      :fetcher github :files
                      ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                       "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
                       "doc/*.texinfo" "lisp/*.el" "docs/dir"
                       "docs/*.info" "docs/*.texi" "docs/*.texinfo"
                       (:exclude ".dir-locals.el" "test.el" "tests.el"
                                 "*-test.el" "*-tests.el" "LICENSE"
                                 "README*" "*-pkg.el"))
                      :source "MELPA" :id which-key :type git
                      :protocol https :inherit t :depth treeless :ref
                      "38d4308d1143b61e4004b6e7a940686784e51500"))
 (with-editor :source "elpaca-menu-lock-file"
   :recipe
   (:package "with-editor" :fetcher github :repo "magit/with-editor"
             :files
             ("*.el" "*.el.in" "dir" "*.info" "*.texi" "*.texinfo"
              "doc/dir" "doc/*.info" "doc/*.texi" "doc/*.texinfo"
              "lisp/*.el" "docs/dir" "docs/*.info" "docs/*.texi"
              "docs/*.texinfo"
              (:exclude ".dir-locals.el" "test.el" "tests.el"
                        "*-test.el" "*-tests.el" "LICENSE" "README*"
                        "*-pkg.el"))
             :source "MELPA" :id with-editor :type git :protocol https
             :inherit t :depth treeless :ref
             "a1f92a26e53033ec58e1d2ce9b132da7ebae816e"))
 (xonsh-mode :source "elpaca-menu-lock-file" :recipe
             (:package "xonsh-mode" :repo "seanfarley/xonsh-mode"
                       :fetcher github :files
                       ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                        "*.texinfo" "doc/dir" "doc/*.info"
                        "doc/*.texi" "doc/*.texinfo" "lisp/*.el"
                        "docs/dir" "docs/*.info" "docs/*.texi"
                        "docs/*.texinfo"
                        (:exclude ".dir-locals.el" "test.el"
                                  "tests.el" "*-test.el" "*-tests.el"
                                  "LICENSE" "README*" "*-pkg.el"))
                       :source "MELPA" :id xonsh-mode :host github
                       :type git :protocol https :inherit t :depth
                       treeless :ref
                       "7fa581524533a9b6b770426e4445e571a69e469d"))
 (xterm-color :source "elpaca-menu-lock-file" :recipe
              (:package "xterm-color" :repo "atomontage/xterm-color"
                        :fetcher github :files
                        ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                         "*.texinfo" "doc/dir" "doc/*.info"
                         "doc/*.texi" "doc/*.texinfo" "lisp/*.el"
                         "docs/dir" "docs/*.info" "docs/*.texi"
                         "docs/*.texinfo"
                         (:exclude ".dir-locals.el" "test.el"
                                   "tests.el" "*-test.el" "*-tests.el"
                                   "LICENSE" "README*" "*-pkg.el"))
                        :source "MELPA" :id xterm-color :type git
                        :protocol https :inherit t :depth treeless
                        :ref
                        "ffdad85e584dfc0857f2a1fb970f5ef0f5d31ba3"))
 (yasnippet :source "elpaca-menu-lock-file" :recipe
            (:package "yasnippet" :fetcher github :repo
                      "joaotavora/yasnippet" :files
                      (:defaults ("doc" "doc/*.org")) :source "MELPA"
                      :id yasnippet :type git :protocol https :inherit
                      t :depth treeless :ref
                      "c1e6ff23e9af16b856c88dfaab9d3ad7b746ad37"))
 (yasnippet-snippets :source "elpaca-menu-lock-file" :recipe
                     (:package "yasnippet-snippets" :repo
                               "AndreaCrotti/yasnippet-snippets"
                               :fetcher github :files
                               ("*.el" "snippets" ".nosearch") :source
                               "MELPA" :id yasnippet-snippets :type
                               git :protocol https :inherit t :depth
                               treeless :ref
                               "606ee926df6839243098de6d71332a697518cb86"))
 (zoom :source "elpaca-menu-lock-file" :recipe
       (:package "zoom" :repo "cyrus-and/zoom" :fetcher github :files
                 ("*.el" "*.el.in" "dir" "*.info" "*.texi" "*.texinfo"
                  "doc/dir" "doc/*.info" "doc/*.texi" "doc/*.texinfo"
                  "lisp/*.el" "docs/dir" "docs/*.info" "docs/*.texi"
                  "docs/*.texinfo"
                  (:exclude ".dir-locals.el" "test.el" "tests.el"
                            "*-test.el" "*-tests.el" "LICENSE"
                            "README*" "*-pkg.el"))
                 :source "MELPA" :id zoom :type git :protocol https
                 :inherit t :depth treeless :ref
                 "5e524d98c7f2b4dd6ed41d95573b29b263632eb2"))
 (zoxide :source "elpaca-menu-lock-file" :recipe
         (:package "zoxide" :fetcher sourcehut :repo
                   "vonfry/zoxide.el" :files
                   ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                    "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
                    "doc/*.texinfo" "lisp/*.el" "docs/dir"
                    "docs/*.info" "docs/*.texi" "docs/*.texinfo"
                    (:exclude ".dir-locals.el" "test.el" "tests.el"
                              "*-test.el" "*-tests.el" "LICENSE"
                              "README*" "*-pkg.el"))
                   :source "MELPA" :id zoxide :type git :protocol
                   https :inherit t :depth treeless :ref
                   "0ec359c83b041c8ffe2ec0e70b16c5d218d9bfd9")))
