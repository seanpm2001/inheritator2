
import "combinator-collections" as c
inherit c.abbreviations
import "utility" as utility
inherit utility.exports
import "kernan-translator" as execTranslator
import "parse-translator" as parseTranslator
import "platform/KernanCompiler" as kc

import "evaluator" as eval
eval.loader := self  //EVIL

import "object-model" as runtime

var ast is public //evil evil dependency inversion

ast := eval.singleton
eval.ng := runtime.singleton
def objectModel = runtime.singleton




var objectModel is public //evil dependency injection

type ASTNode = interface { } 

def modules = dictionary[[String, ASTNode]]

def moduleIsBeingLoaded = object { method isLoaded { false } } 


method loadModule(name : String) { 
  def mod = modules.at(name) ifAbsent {
      modules.at(name) put(moduleIsBeingLoaded)

      
      def newModuleCommonTree =
              optionTranslator.value.translateFile(name)
      if (optionDump.value) then {newModuleCommonTree.dump}
      if (optionNoRun.value) then {return done} //dunno what else to return!

      def newModule = newModuleCommonTree.eval(objectModel.context)
      modules.at(name) put(newModule)
      return newModule
  }

  if (!mod.isLoaded) then {error "Module {name} is Loading - circular import" }
  
  return mod
}


def optionNoRun = default(false) named "no run"
def optionDump = default(false) named "dump"
def optionTranslator = default( parseTranslator) named "parser"
var somethingLoaded := false

method loadModulesFromArguments {
  for (kc.args) do { arg ->
    match (arg)
      case { "--no-run" -> optionNoRun <- true}
      case { "--dump" -> optionDump <- true}
      case { "--about" ->
           print "inheritator2 (c) James Noble"
           print "bits stolen from Michael Homer, Andrew Black, Kim Bruce, Tim Jones, Isaac Oscar Gariano" }
      case { "--exec" -> 
             if (somethingLoaded) then {crash "can't change parser after loading" }
             optionTranslator <- execTranslator } 
      case { _ ->
             loadFilename(arg)
             somethingLoaded := true} 
  }
}

method loadFilename(fileName) {
    def nameSize = fileName.size
    def baseName = 
      if ((fileName.substringFrom(nameSize - 5) to(nameSize)) == ".grace")
        then { fileName.substringFrom(1)to(nameSize - 6) }
        else { fileName }
    loadModule( baseName )
}



method installIntrinsicModule(intrinsicModuleObject) {
  modules.at(INTRINSICMODULE) put(intrinsicModuleObject)
}
