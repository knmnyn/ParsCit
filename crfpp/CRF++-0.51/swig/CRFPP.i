%module CRFPP
%include exception.i
%{
#include "crfpp.h"
%}

%newobject surface;

%exception {
  try { $action }
  catch (char *e) { SWIG_exception (SWIG_RuntimeError, e); }
  catch (const char *e) { SWIG_exception (SWIG_RuntimeError, (char*)e); }
}

%feature("notabstract") CRFPP::Tagger;

%ignore CRFPP::createTagger;
%ignore CRFPP::getTaggerError;

%extend CRFPP::Tagger { Tagger(const char *argc); }

%{

void delete_CRFPP_Tagger (CRFPP::Tagger *t) {
  delete t;
  t = 0;
}

CRFPP::Tagger* new_CRFPP_Tagger (const char *arg) {
  CRFPP::Tagger *tagger = CRFPP::createTagger(arg);
  if (! tagger) throw CRFPP::getTaggerError();
  return tagger;
}

%}

%include ../crfpp.h
%include version.h
