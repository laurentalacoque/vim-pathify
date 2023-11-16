# Test file for pathify
# '@@' is replaced with <path/to/plugin>/test/fakepath

# begin test
setenv MODULE1 = "@@/projects/proj1/module1"
setenv MODULE1INC = "@@/projects/proj1/module1/include/"
setenv MODULE2 = "@@/projects/proj1/module2"
setenv PROJ2SRC = "@@/projects/proj2/proj2.c"
# end test

# begin test2
setenv MODULE1 = "@@/projects/proj1/module1"
setenv MODULE1INC = "$MODULE1/include/"
setenv HEADER = "$MODULE1/include/module1.h"
# end test2
