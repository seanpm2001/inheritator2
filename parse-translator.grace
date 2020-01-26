//NOTES needs to run with clean-git kernan
//because that's got correct kernan-compiler parse-nodes patch

import "combinator-collections" as c
inherit c.abbreviations


import "utility" as utility
inherit utility.exports

import "platform/KernanCompiler" as kc
def pn = kc.parseNodes
def parseNodes = pn


var jast is public //evil evil dependency inversion



import "loader" as loader
import "evaluator" as eval
import "object-model" as runtime

jast := eval.singleton
eval.ng := runtime.singleton
def objectModel = runtime.singleton


type ASTNode = interface { }

def modules = dictionary[[String, ASTNode]]

def moduleIsBeingLoaded = object { method isLoaded { false } }

def indent = ""
def breakLines = true


print "tests"

def hw =  "print \"Hello World\""
print "hw=**{hw}**"
def ast01 = kc.parse(hw)
print (ast01)
print (ast01.get_Body.at(0))
def trn01 = translate(ast01)
print (trn01)
print (trn01.body)

print "loading intrinsic"

loader.installIntrinsicModule( objectModel.intrinsicModuleObject )


print "run"


print(trn01.eval(objectModel.intrinsicModuleObject))



method mapCommon(c) { map { each -> common(each) } over(c) }
method common(j) { translate(j) }

method mapArray(arr) {
    def ret = list
    def size = arr.get_Count
    for (0 .. (size - 1)) do { i ->
        ret.add(translate(arr.at(i)))
    }
    ret
}

//method source(n) { "{n.get_Column} @ {n.get_Line}" }
method source(n) { n.get_Token }


def pnObject = parseNodes.Object
def pnNumber = parseNodes.Number
def pnStringLiteral = parseNodes.StringLiteral
def pnInterpolatedString = parseNodes.InterpolatedString
def pnIdentifier = parseNodes.Identifier
def pnOperator = parseNodes.Operator
def pnMethodDeclaration = parseNodes.MethodDeclaration
def pnSignature = parseNodes.Signature
def pnSignaturePart = parseNodes.SignaturePart
def pnClassDeclaration = parseNodes.ClassDeclaration
def pnTraitDeclaration = parseNodes.TraitDeclaration
def pnImplicitReceiverRequest = parseNodes.ImplicitReceiverRequest
def pnExplicitReceiverRequest = parseNodes.ExplicitReceiverRequest
def pnTypedParameter = parseNodes.TypedParameter
def pnBlock = parseNodes.Block
def pnVarDeclaration = parseNodes.VarDeclaration
def pnDefDeclaration = parseNodes.DefDeclaration
def pnParenthesised = parseNodes.Parenthesised
def pnComment = parseNodes.Comment
def pnReturn = parseNodes.Return
def pnInherits = parseNodes.Inherits
def pnUses = parseNodes.Uses
def pnAlias = parseNodes.Alias
def pnExclude = parseNodes.Exclude
def pnBind = parseNodes.Bind
def pnDialect = parseNodes.Dialect
def pnImport = parseNodes.Import
def pnVarArgsParameter = parseNodes.VarArgsParameter
def pnPrefixOperator = parseNodes.PrefixOperator
def pnAnnotations = parseNodes.Annotations
def pnExplicitBracketRequest = parseNodes.ExplicitBracketRequest
def pnInterface = parseNodes.Interface
def pnTypeStatement = parseNodes.TypeStatement




for (kc.args) do { fileName ->
    def nameSize = fileName.size
    def baseName =
      if ((fileName.substringFrom(nameSize - 5) to(nameSize)) == ".grace")
        then { fileName.substringFrom(1)to(nameSize - 6) }
        else { fileName }
    loadModule( baseName )
}


method loadModule(name : String) {
  def mod = modules.at(name) ifAbsent {
      modules.at(name) put(moduleIsBeingLoaded)
      def newModuleParseTree = kc.parseFile(name ++ ".grace")
      def newModuleCommonTree = translate(newModuleParseTree)
      print "translated: {newModuleCommonTree}"
      def newModule = newModuleCommonTree.eval(objectModel.intrinsicModuleObject)
      modules.at(name) put(newModule)
      return newModule
  }

  if (!mod.isLoaded) then {error "Module {name} is Loading - circular import" }
  return mod
}






// Examine a node and decide where to send it. Each of the methods
// below addresses one kind of node and converts it into a string,
// concatenating its child nodes in as required.
method translate(obj) {
    print "translate: {obj}"
    match (obj)
        case { n : pn.Number -> translateNumber(n) }
        case { n : pn.StringLiteral -> translateStringLiteral(n) }
        case { n : pn.InterpolatedString ->
            translateInterpolatedString(n) }
        case { o : pn.Operator -> translateOperator(o) }
        case { o : pn.MethodDeclaration ->
            translateMethodDeclaration(o) }
        case { o : pn.ClassDeclaration ->
            translateClassDeclaration(o) }
        case { o : pn.TraitDeclaration ->
            translateTraitDeclaration(o) }
        case { p : pn.SignaturePart -> translateSignaturePart(p) }
        case { s : pn.Signature -> translateSignature(s) }
        case { o : pn.Object -> translateObject(o) }
        case { r : pn.ImplicitReceiverRequest ->
            translateImplicitReceiverRequest(r) }
        case { r : pn.ExplicitReceiverRequest ->
            translateExplicitReceiverRequest(r) }
        case { o : pn.Identifier -> translateIdentifier(o) }
        case { r : pn.TypedParameter ->
            translateTypedParameter(r) }
        case { b : pn.Block -> translateBlock(b) }
        case { b : pn.VarDeclaration -> translateVarDeclaration(b) }
        case { b : pn.DefDeclaration -> translateDefDeclaration(b) }
        case { b : pn.Parenthesised -> translateParenthesised(b) }
        case { b : pn.Comment -> translateComment(b) }
        case { b : pn.Return -> translateReturn(b) }
        case { b : pn.Inherits -> translateInherits(b) }
        case { b : pn.Uses -> translateUses(b) }
        case { b : pn.Bind -> translateBind(b) }
        case { b : pn.Dialect -> translateDialect(b) }
        case { b : pn.Import -> translateImport(b) }
        case { b : pn.VarArgsParameter ->
            translateVarArgsParameter(b) }
        case { b : pn.PrefixOperator ->
            translatePrefixOperator(b) }
        case { b : pn.Annotations -> translateAnnotations(b) }
        case { r : pn.ExplicitBracketRequest ->
            translateExplicitBracketRequest(r) }
        case { b : pn.Interface -> translateInterface(b) }
        case { b : pn.TypeStatement -> translateTypeStatement(b) }
        case { _ ->
                print "Printer does not support node type {obj}"
                "<<Untranslated: {obj}>>"
            }
}

method translateStatement(o) {
    //mwh's pp had this  - not sure we need it but keeping it for now
    //this is NOT a leg of  translate(_) above!
    //TODO decide about comments - make a jast.comment decorator?
    translate(o)
}

method translateNumber(n) {
  //hacked from mwh's AST.cs

            def numbase = n.get_NumericBase
            var integral := 0
            var fractional := 0
            var size := 1
            var frac := false
            for (n.get_Digits) do { c ->
                if (c == ".")
                  then { frac := true }
                  elseif {!frac}
                  then {
                    integral := integral * numbase
                    integral := integral + digit(c)
                     }
                  else {
                    size := size / numbase
                    fractional := fractional + (size * digit(c))
                }
            }
            def val = integral + fractional

            jast.numberLiteralNode(val) at(source(n))
}

method ord(c) { c.codepoints.at(1).codepoint }
method digit(c) {
               if ((c >= "0") && (c <= "9"))
                 then { ord(c) - ord "0" }
                 elseif {(c >= "a") && (c <= "z")}
                 then { (ord(c) - ord "a") + 10 }
                 elseif {(c >= "A") && (c <= "Z")}
                 then { (ord(c) - ord "A") + 10 }
                 else { error "FATAL BAD DIGIT {c} should be cautn in parser" }
}

method translateStringLiteral(s) {
    jast.stringLiteralNode(s.get_Raw) at(source(s))
}

method translateInterpolatedString(s) {
    def rcvr = jast.stringLiteralNode( "" ) at (source(s))

    def parts = s.get_Parts
    def partCount = parts.get_Count
    def args = list

    // Native lists are available as objects with a Count property
    // that can be indexed using .at. These lists are zero-indexed
    // as the host is, and do not yet support iteration.
    for (0 .. (partCount - 1)) do { i ->
        def part = parts.at(i)
        print "part {i}={part}"
        args.add ( match(part)
            case { _ : pn.StringLiteral -> jast.stringLiteralNode(part.get_Raw)  at (source(s)) }
            case { _ -> jast.explicitRequestNode(translate(part), "asString", empty, empty) at (source(s)) } )
    }

    args.reverse
    var first := true
    var rv := jast.stringLiteralNode("") at(source(s))

    for (args) do { a ->
        if (first) then {
             first := false
             rv := a }
          else {
             rv :=
                 jast.explicitRequestNode(a, "++(_)", empty, list(rv)) at (source(s))           }
    }

    rv
}

method translateIdentifier(i) {
    jast.implicitRequestNode(i.get_Name, empty, empty) at (i)
}

method translateOperator(o) {
     jast.explicitRequestNode(
        translate(o.get_Left), // receiver
        o.get_Name ++ "(_)", // name
        empty, //type arguments
        list( translate(o.get_Right) ) ) //arguments
              at(o)
}


method helper_Generics(g) {  //TODO
    def gCount = g.get_Count
    if (gCount == 0) then {
        return ""
    }
    var ret := "[["
    for (0 .. (gCount - 1)) do { i ->
        if (i > 0) then {
            ret := ret ++ ", "
        }
        ret := ret ++ translate(g.at(i))
    }
    "{ret}]]"
}

method translateClassDeclaration(m) {  //TODO
    var ret := "class "
    ret := ret ++ translate(m.get_Signature)
    ret := ret ++ " \{\n"
    def body = m.get_Body
    def count = body.get_Count
    for (0 .. (count - 1)) do {i->
        def node = body.at(i)
        ret := ret ++ translateStatement(node)
    }
    "{ret}{indent}\}"}

method translateTraitDeclaration(m) {   //TODO
    var ret := "trait "
    ret := ret ++ translate(m.get_Signature)
    ret := ret ++ " \{\n"
    def body = m.get_Body
    def count = body.get_Count
    for (0 .. (count - 1)) do {i->
        def node = body.at(i)
        ret := ret ++ translateStatement(node)
    }
    "{ret}{indent}\}"}

method translateMethodDeclaration(m) {  //TODO
    //jast.methodNode( translateSignature( m.get_Signature ),
    //                 translateAll  HEREH
    var ret := "method "
    ret := ret ++ translate(m.get_Signature)
    ret := ret ++ " \{\n"
    def body = m.get_Body
    def count = body.get_Count
    for (0 .. (count - 1)) do {i->
        def node = body.at(i)
        ret := ret ++ translateStatement(node)
    }
    "{ret}{indent}\}" }

method translateSignaturePart(p) {
    def name = p.get_Name
    def params = p.get_Parameters
    def genericParameters = p.get_GenericParameters
    var ret := "{name}"
    if (genericParameters.get_Count > 0) then {
        ret := ret ++ "[["
        for (0 .. (genericParameters.get_Count - 1)) do { i ->
            if (i > 0) then {
                ret := ret ++ ","
            }
            ret := ret ++ translate(genericParameters.at(i))
        }
        ret := ret ++ "]]"
    }
    if (params.get_Count > 0) then {
        ret := ret ++ "("
        for (0 .. (params.get_Count - 1)) do { i ->
            if (i > 0) then {
                ret := ret ++ ","
            }
            ret := ret ++ translate(params.at(i))
        }
        ret := ret ++ ")"
    }
    ret   //TODO
}

method translateSignature(s) {
    def parts = s.get_Parts
    def returnType = s.get_ReturnType
    def size = parts.get_Count
    var ret := ""
    for (0 .. (size - 1)) do { i ->
        ret := ret ++ translate(parts.at(i))
    }
    if (!returnType.isNull) then {
        ret := ret ++ " -> " ++ translate(returnType)
    }
    if (!s.get_Annotations.isNull) then {
        ret := ret ++ translate(s.get_Annotations)
    }
    ret   //TODO
}


method translateObjectBody(body) {
    def ret = list
    def count = body.get_Count

    print "translateObejctBody size={count} body={body}"
    for (0 .. (count - 1)) do {i->
        def node = body.at(i)
        print "  node{i}={node}"
        ret.add(translate(node))
        print "  ret{i}={ret.size}"
        print "  ret{i}={ret}"
    }

    print "translatdObjectObject={ret}"
    ret
}

method translateObject(o) {
    def comment = o.get_Comment //ignoring comments
    def origin = "missing" ///to do with brands/annotations, see evaluator
    def source = source(o)
    jast.objectConstructorNode(translateObjectBody(o.get_Body),origin) at(source)
}

method translateImplicitReceiverRequest(r) {
    //cut and pasted from visitSignature
    //there should be some commonality, should reafactor
    var name := ""
    var typeArguments := list
    var arguments := list

    def nameParts = r.get_NameParts
    def argLists = r.get_Arguments
    def genArgLists = r.get_GenericArguments
    def size = nameParts.get_Count

    //handle each part
    for (0 .. (size - 1)) do { i ->
        def partName = nameParts.at(i).get_Name
        name := name ++ splunge(partName)
        def args = argLists.at(i)
        def argCount = args.get_Count

        //Generic args aren't part of request names apparently...

        if ((size > 1) || (argCount > 0)) then {
           name := name ++ munge(args, "(", "_", ",", ")") }

        typeArguments := typeArguments ++ mapArray(genArgLists.at(i))
        arguments := arguments ++ mapArray(args)
    }

    jast.implicitRequestNode(name, typeArguments, arguments) at(source(r))
}

method translateExplicitReceiverRequest(r) {
    def irr = translateImplicitReceiverRequest(r)   //EVIL
    def receiver = r.get_Receiver
    jast.explicitRequestNode( translate(receiver),
        irr.name, irr.typeArguments, irr.arguments) at(irr.source)
}

method translateTypedParameter(p) { //TODO
    "{translate(p.get_Name)} : {translate(p.get_Type)}"
}

method translateBlock(b) {
    jast.blockNode(
        translate(b.get_Parameters),
        translate(b.get_Body)) at (b)
}

method translateVarDeclaration(v) {
    var ret := "var "
    ret := ret ++ translate(v.get_Name)
    if (!v.get_Annotations.isNull) then {
        ret := ret ++ translate(v.get_Annotations)
    }
    if (!v.get_Value.isNull) then {
        ret := ret ++ " := "
        ret := ret ++ translate(v.get_Value)
    }
    ret   //TODO
}

method translateDefDeclaration(v) {
    var ret := "def "
    ret := ret ++ translate(v.get_Name)
    if (!v.get_Annotations.isNull) then {
        ret := ret ++ translate(v.get_Annotations)
    }
    ret := ret ++ " = "
    ret := ret ++ translate(v.get_Value)
    ret   //TODO
}

method translateParenthesised(p) {  //TODO
    def newIndent = indent ++ "    "
    "({translate(p.get_Expression, newIndent)})"
}

method translateComment(c) {   //TODO
    def comment = c.get_Comment
    if (!comment.isNull) then {
        "//{c.get_Value}\n{indent}{translate(comment)}"
    } else {
        "//{c.get_Value}"
    }
}


method translateReturn(p) {   //TODO
    if (p.get_ReturnValue.isNull) then {
        return "return"
    }
    def newIndent = indent ++ "    "
    "return {translate(p.get_ReturnValue, newIndent)}"
}

method translateInherits(p) {   //TODO
    def newIndent = indent ++ "    "
    def aliases = p.get_Aliases
    def excludes = p.get_Excludes
    var ret := "inherit {translate(p.get_From, newIndent)}"
    if (aliases.get_Count > 0) then {
        ret := ret ++ translateAliases(aliases, newIndent)
    }
    if (excludes.get_Count > 0) then {
        ret := ret ++ translateExcludes(excludes, newIndent)
    }
    ret
}

method translateUses(p) {   //TODO
    def newIndent = indent ++ "    "
    def aliases = p.get_Aliases
    def excludes = p.get_Excludes
    var ret := "use {translate(p.get_From, newIndent)}"
    if (aliases.get_Count > 0) then {
        ret := ret ++ translateAliases(aliases, newIndent)
    }
    if (excludes.get_Count > 0) then {
        ret := ret ++ translateExcludes(excludes, newIndent)
    }
    ret
}

method translateAliases(aliases) {   //TODO
    def ac = aliases.get_Count
    var ret := ""
    def newIndent = indent ++ "    "
    for (0 .. (ac - 1)) do { i ->
        def a = aliases.at(i)
        ret := ret ++ "\n" ++ indent ++ "alias "
            ++ translate(a.get_NewName, newIndent)
            ++ " = "
            ++ translate(a.get_OldName, newIndent)
    }
    ret
}

method translateExcludes(excludes) {   //TODO
    def ac = excludes.get_Count
    var ret := ""
    def newIndent = indent ++ "    "
    for (0 .. (ac - 1)) do { i ->
        def a = excludes.at(i)
        ret := ret ++ "\n" ++ indent ++ "exclude "
            ++ translate(a.get_Name, newIndent)
    }
    ret
}

method translateBind(o) {
    print "translateBind"
    print "translateBind from {o.get_Left}"
    print "translateBind to {translate(o.get_Left)}"
    translate(o.get_Left).evilMakeBind(translate(o.get_Right))
}

method translateDialect(d, ind) {   //TODO
    "dialect \"{d.get_Path.get_Raw}\""
}

method translateImport(d) {
    jast.importNode(d.get_Path.get_Raw, d.get_Name, d.get_Type)
               at(source(d))

    //"import \"{d.get_Path.get_Raw}\" as {translate(d.get_Name, ind)}"
}

method translateVarArgsParameter(v, ind) {   //TODO
    "*{translate(v.get_Name, ind)}"
}

method translatePrefixOperator(o, ind) {    //TODO
    "{o.get_Name}{translate(o.get_Receiver, ind)}"
}

method translateAnnotations(o, ind) {   //TODO
    var ret := " is "
    def anns = o.get_Annotations
    def annCount = o.get_Annotations.get_Count
    for (0 .. (annCount - 1)) do { i ->
        def a = anns.at(i)
        if (i > 0) then {
            ret := ret ++ ", "
        }
        ret := ret ++ translate(a, ind)
    }
    ret
}

method translateExplicitBracketRequest(b) {    //TODO
    var ret := "{translate(b.get_Receiver)}{b.get_Token.get_Name}"
    def args = b.get_Arguments
    def argc = args.get_Count
    for (0 .. (argc - 1)) do { i ->
        if (i > 0) then {
            ret := ret ++ ", "
        }
        ret := ret ++ translate(args.at(i))
    }
    "{ret}{b.get_Token.get_Other}"
}

method translateInterface(o) {   //TODO
    var ret := "interface \{\n"
    ret := ret ++ translateObjectBody(o.get_Body)
    "{ret}{indent}\}"
}

method translateTypeStatement(t) {    //TODO
    "type {translate(t.get_BaseName)}{helper_Generics(t.get_GenericParameters)} = " ++
        translate(t.get_Body)
}




//return a string of arguments in canonical names
method munge( spart, left, mid, sep, right ) {
        if (spart.get_Count == 0) then { return left ++ right }
        var result := left
        for (1 .. (spart.get_Count - 1)) do { p ->
          result := result ++ mid ++ sep
          }
        result ++ mid ++ right
}

//return only the name part of a name with parenthesis
method splunge( namewithparens ) {
       var idx := 0
       for ( namewithparens ) do { c ->
           if (c == "(")
              then { return namewithparens.substringFrom(1)to(idx) }
           idx := idx + 1
       }
       namewithparens
}
