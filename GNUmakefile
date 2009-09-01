include $(GNUSTEP_MAKEFILES)/common.make

-include config.make

PACKAGE_NAME = WebServices
PACKAGE_VERSION = 0.3.0
CVS_MODULE_NAME = gnustep/dev-libs/WebServices
CVS_TAG_NAME = WebServices
SVN_BASE_URL=svn+ssh://svn.gna.org/svn/gnustep/libs
SVN_MODULE_NAME=webservices

NEEDS_GUI = NO

TEST_TOOL_NAME=

LIBRARY_NAME=WebServices
DOCUMENT_NAME=WebServices

WebServices_INTERFACE_VERSION=0.3

WebServices_OBJC_FILES +=\
        WebServices.m \
	GWSBinding.m \
	GWSCoder.m \
	GWSDocument.m \
	GWSElement.m \
	GWSExtensibility.m \
	GWSMessage.m \
	GWSPort.m \
	GWSPortType.m \
	GWSService.m \
	GWSSOAPCoder.m \
	GWSXMLRPCCoder.m \
	WSSUsernameToken.m \


WebServices_HEADER_FILES += \
	WebServices.h \
	GWSBinding.h \
	GWSCoder.h \
	GWSConstants.h \
	GWSDocument.h \
	GWSElement.h \
	GWSExtensibility.h \
	GWSMessage.h \
	GWSPort.h \
	GWSPortType.h \
	GWSService.h \
	GWSType.h \
	WSSUsernameToken.h \


WebServices_AGSDOC_FILES += \
	WebServices.gsdoc \
	WebServices.h \
	GWSBinding.h \
	GWSCoder.h \
	GWSConstants.h \
	GWSDocument.h \
	GWSElement.h \
	GWSExtensibility.h \
	GWSMessage.h \
	GWSPort.h \
	GWSPortType.h \
	GWSService.h \
	GWSType.h \
	WSSUsernameToken.h \


WebServices_AGSDOC_FLAGS = \
	-MakeFrames YES \
	-ConstantsTemplate TypesAndConstants \

# Optional Java wrappers for the library
JAVA_WRAPPER_NAME = WebServices

#
# Assume that the use of the gnu runtime means we have the gnustep
# base library and can use its extensions to build WebServices stuff.
#
ifeq ($(OBJC_RUNTIME_LIB),gnu)
APPLE=0
else
APPLE=1
endif

ifeq ($(APPLE),1)
ADDITIONAL_OBJC_LIBS += -lgnustep-baseadd
WebServices_LIBRARIES_DEPEND_UPON = -lgnustep-baseadd
endif

WebServices_HEADER_FILES_INSTALL_DIR = WebServices

TEST_TOOL_NAME+=testWebServices
testWebServices_OBJC_FILES = testWebServices.m
testWebServices_TOOL_LIBS += -lWebServices
testWebServices_LIB_DIRS += -L./$(GNUSTEP_OBJ_DIR)

-include GNUmakefile.preamble

include $(GNUSTEP_MAKEFILES)/library.make
include $(GNUSTEP_MAKEFILES)/test-tool.make
include $(GNUSTEP_MAKEFILES)/documentation.make

-include GNUmakefile.postamble
