# Creates types and helper functions to 
# garanty the coherency of mesurement units
# before compilation

# An array of exponents is called a "composition"
# A type name in called a uname
# A type defined only one exponent is called a "basic unit"

import macros
import sequtils
import strutils
import tables
import math

type
    # Sequence containing a "composition", i.e. exponents of the basic units 
    TComposition = seq[int]
    # Definition of a basic unit
    TBasicUnit* = tuple
        name:string
        limits:TExpLimits
    # Configuration of basic units 
    TBasicUnitsConf* = seq[TBasicUnit]
    # Definition of an alias 
    TAlias* = tuple
        name:string # Full name
        compo:TComposition # Dimensions    
    # Config for aliases 
    TAliasConf* = seq[TAlias]
    # Config of powers to handle
    TExpLimits = tuple
        expmin:int # Maximum negative exponent to define
        expmax:int # Maximum positive exponent to define
    # Config for the name of the types
    TUnameConfig* = tuple
        prefix: string  # First character(s) of the type name
        neg_sep:string # Prefix for negative exponents
        nodim:string # Name of the "no dimension" unit

# Helper function for debug
proc `$` (c: TComposition): string =
    result = ""
    for i in 0..c.len-1:
        result &= $c[i] & " "

# Create the name of a type give a composition and some config
proc get_uname(compo: TComposition, config: TBasicUnitsConf, uname_config: TUnameConfig) : string {.compileTime.} =
    var
        n:int
        first_char: bool = true # used to prevent an underscore as first char if first unit is absent.
    result = uname_config.prefix

    n = -1
    for exp in compo:
        n += 1 
        if exp == 0:
            continue
        if n > 0 and not first_char:
            result &= "_"
        result = result & config[n].name
        first_char = false
        # Add separator if exponent is negative
        # Nothing to display if exponent is 1
        if exp<0:
            result &= uname_config.neg_sep
            result &= $(-exp)
        elif exp>1:
            result &= $exp

# Comparaiso function for composition
proc `==` (a, b: TComposition) : bool =
    # Assuming size are equal for compo
    for i in 0..a.high:
        if a[i] != b[i]:
            return false
    return true

# Give full name (human) from a composition
proc get_fullname(compo: TComposition, config: TBasicUnitsConf) : string {.compileTime.} =
    var 
        z = zip(compo, config)
        sep = ' '
    result = "" 
    for n in z:
        if n.a != 0:
            result = result & sep & n.b.name
        sep = '.'
        if n.a > 1 or n.a < 0:
            result = result & '^' & intToStr(n.a)

# Initialilisation of the librairy
macro init_unit*(config: static[TBasicUnitsConf], uname_config: static[TUnameConfig], aliases_config:static[TAliasConf]) : stmt =   # TODO add default value for alias
    var
       compos: seq[TComposition] = @[]
       unames: seq[string] = @[]
       compo: TComposition = @[]
       idx: int
       conf_length: int
       fullnames: TTable[TComposition, string]

    result = newNimNode(nnkStmtList)

    conf_length = config.len

    for c in config:
        compo.add(c.limits.expmin)
    compos.add(compo)
    idx = conf_length-1

    # Following combinations
    block compos_loop:
        while true:
            while compo[idx] == config[idx].limits.expmax:
                compo[idx] = config[idx].limits.expmin
                if idx == 0:
                    break compos_loop
                else:
                    idx = idx - 1
            compo[idx] = compo[idx] + 1 # TODO temp, regression with +=
            idx = conf_length-1
            compos.add(compo)

    ## List of names associated to composition
    echo "**", uname_config.prefix # TODO needed, don't know why. 
    for c in compos:
        unames.add(get_uname(c, config, uname_config))
    
    # Correct name for constants (only zeros in composition)
    idx = unames.find(uname_config.prefix)
    unames[idx] = uname_config.prefix & uname_config.nodim
    ## Imports
    var imp : PNimrodNode = newNimNode(nnkImportStmt)
    imp.add(newStrLitNode("strutils"))
    result.add(imp)

    ## Definition of types
    var types: PNimrodNode = newNimNode(nnkTypeSection)
    for uname in unames:
        var td:PNimrodNode = newNimNode(nnkTypeDef)
        td.add(newNimNode(nnkPostfix).add(newIdentNode("*")).add(newIdentNode(uname)))
        td.add(newEmptyNode()) # TODO why are paren needed ?
        td.add(newNimNode(nnkDistinctTy).add(newIdentNode("float")))
        types.add(td)

    ## Definition of aliases
    for al in aliases_config:
        var ta:PNimrodNode = newNimNode(nnkTypeDef)
        ta.add(newNimNode(nnkPostfix).add(newIdentNode("*")).add(newIdentNode(uname_config.prefix & al.name)))
        ta.add(newEmptyNode()) # TODO why are paren needed ?
        ta.add(newIdentNode(get_uname(al.compo, config, uname_config)))
        types.add(ta)

    ## Definition of the type class including all new types (not aliases)
    var tc:PNimrodNode = newNimNode(nnkTypeDef)
   
    tc.add(newNimNode(nnkPostfix).add(newIdentNode("*")).add(newIdentNode("TU")))
    tc.add(newEmptyNode())
    var infi: PNimrodNode = infix(newIdentNode(unames[0]), "or", newIdentNode(unames[1]))
    for idx in 2..high(unames)-1:
        var infi_tmp = infi.copy
        infi = infix(infi_tmp, "or", newIdentNode(unames[idx]))
    var infi_tmp = infi.copy
    infi = infix(infi_tmp, "or", newIdentNode(unames[high(unames)]))
    tc.add(infi)
    types.add(tc)
    result.add(types)

    ## Procedures
    for idx_c in 0..high(compos):
        # Addition
        block:
            var procAdd = newNimNode(nnkProcDef)
            var name = newNimNode(nnkPostfix)
            name.add(newIdentNode("*"))
            name.add(newNimNode(nnkAccQuoted).add(newIdentNode("+")))
            procAdd.add(name)
            procAdd.add(newEmptyNode())
            procAdd.add(newEmptyNode())
            var formalParams = newNimNode(nnkFormalParams)
            formalParams.add(newIdentNode(unames[idx_c]))
            formalParams.add(newIdentDefs(newIdentNode("a"), newIdentNode(unames[idx_c])))
            formalParams.add(newIdentDefs(newIdentNode("b"), newIdentNode(unames[idx_c])))
            procAdd.add(formalParams)
            procAdd.add(newEmptyNode())
            procAdd.add(newEmptyNode())
            var 
                body = newNimNode(nnkStmtList)
                op_lhs = newDotExpr(newIdentNode("a"), newIdentNode("float"))
                op_rhs = newDotExpr(newIdentNode("b"), newIdentNode("float"))
                assig_lhs = newIdentNode("result")
                assig_rhs = newDotExpr(newNimNode(nnkPar).add(infix(op_lhs, "+", op_rhs)), newIdentNode(unames[idx_c]))
            body.add(newAssignment(assig_lhs, assig_rhs))
            procAdd.add(body)
            result.add(procAdd)

        # Substraction
        block:
            var procSub = newNimNode(nnkProcDef)
            var name = newNimNode(nnkPostfix)
            name.add(newIdentNode("*"))
            name.add(newNimNode(nnkAccQuoted).add(newIdentNode("-")))
            procSub.add(name)
            procSub.add(newEmptyNode())
            procSub.add(newEmptyNode())
            var formalParams = newNimNode(nnkFormalParams)
            formalParams.add(newIdentNode(unames[idx_c]))
            formalParams.add(newIdentDefs(newIdentNode("a"), newIdentNode(unames[idx_c])))
            formalParams.add(newIdentDefs(newIdentNode("b"), newIdentNode(unames[idx_c])))
            procSub.add(formalParams)
            procSub.add(newEmptyNode())
            procSub.add(newEmptyNode())
            var 
                body = newNimNode(nnkStmtList)
                op_lhs = newDotExpr(newIdentNode("a"), newIdentNode("float"))
                op_rhs = newDotExpr(newIdentNode("b"), newIdentNode("float"))
                assig_lhs = newIdentNode("result")
                assig_rhs = newDotExpr(newNimNode(nnkPar).add(infix(op_lhs, "-", op_rhs)), newIdentNode(unames[idx_c]))
            body.add(newAssignment(assig_lhs, assig_rhs))
            procSub.add(body)
            result.add(procSub)

    for idx1 in 0..high(compos):
        for idx2 in 0..high(compos):
            var
                res_compo: TComposition = @[]
                uname_res_idx : int

            # Multiplication
            for idx in 0..conf_length-1:
                res_compo.add(compos[idx1][idx] + compos[idx2][idx])
            uname_res_idx = find[seq[TComposition], TComposition](compos, res_compo)
            
            if uname_res_idx != -1:
                var procMult = newNimNode(nnkProcDef)
                var name = newNimNode(nnkPostfix)
                name.add(newIdentNode("*"))
                name.add(newNimNode(nnkAccQuoted).add(newIdentNode("*")))
                procMult.add(name)
                procMult.add(newEmptyNode())
                procMult.add(newEmptyNode())
                var formalParams = newNimNode(nnkFormalParams)
                formalParams.add(newIdentNode(unames[uname_res_idx]))
                formalParams.add(newIdentDefs(newIdentNode("a"), newIdentNode(unames[idx1])))
                formalParams.add(newIdentDefs(newIdentNode("b"), newIdentNode(unames[idx2])))
                procMult.add(formalParams)
                procMult.add(newEmptyNode())
                procMult.add(newEmptyNode())
                var 
                    body = newNimNode(nnkStmtList)
                    op_lhs = newDotExpr(newIdentNode("a"), newIdentNode("float"))
                    op_rhs = newDotExpr(newIdentNode("b"), newIdentNode("float"))
                    assig_lhs = newIdentNode("result")
                    assig_rhs = newDotExpr(newNimNode(nnkPar).add(infix(op_lhs, "*", op_rhs)), newIdentNode(unames[uname_res_idx]))
                body.add(newAssignment(assig_lhs, assig_rhs))
                procMult.add(body)
                result.add(procMult)
            
            res_compo = @[]

            # Division
            for idx in 0..conf_length-1:
                res_compo.add(compos[idx1][idx] - compos[idx2][idx])
            uname_res_idx = find[seq[TComposition], TComposition](compos, res_compo)
            
            if uname_res_idx != -1:
                var procDiv = newNimNode(nnkProcDef)
                var name = newNimNode(nnkPostfix)
                name.add(newIdentNode("*"))
                name.add(newNimNode(nnkAccQuoted).add(newIdentNode("/")))
                procDiv.add(name)
                procDiv.add(newEmptyNode())
                procDiv.add(newEmptyNode())
                var formalParams = newNimNode(nnkFormalParams)
                formalParams.add(newIdentNode(unames[uname_res_idx]))
                formalParams.add(newIdentDefs(newIdentNode("a"), newIdentNode(unames[idx1])))
                formalParams.add(newIdentDefs(newIdentNode("b"), newIdentNode(unames[idx2])))
                procDiv.add(formalParams)
                procDiv.add(newEmptyNode())
                procDiv.add(newEmptyNode())
                var 
                    body = newNimNode(nnkStmtList)
                    op_lhs = newDotExpr(newIdentNode("a"), newIdentNode("float"))
                    op_rhs = newDotExpr(newIdentNode("b"), newIdentNode("float"))
                    assig_lhs = newIdentNode("result")
                    assig_rhs = newDotExpr(newNimNode(nnkPar).add(infix(op_lhs, "/", op_rhs)), newIdentNode(unames[uname_res_idx]))
                body.add(newAssignment(assig_lhs, assig_rhs))
                procDiv.add(body)
                result.add(procDiv)
    
    # Comparaison functions
    for op in ["<", ">", "==", "<=", ">="]:
        var procComp = newNimNode(nnkProcDef)
        var name = newNimNode(nnkPostfix)
        name.add(newIdentNode("*"))
        name.add(newNimNode(nnkAccQuoted).add(newIdentNode(op)))
        procComp.add(name)

        procComp.add(newEmptyNode())
        procComp.add(newEmptyNode())
        var formalParams = newNimNode(nnkFormalParams)
        formalParams.add(newIdentNode("bool"))
        formalParams.add(newIdentDefs(newIdentNode("a"), newIdentNode("TU")))
        formalParams.add(newIdentDefs(newIdentNode("b"), newIdentNode("TU")))
        procComp.add(formalParams)
        procComp.add(newEmptyNode())
        procComp.add(newEmptyNode())
        var 
            body = newNimNode(nnkStmtList)
            op_lhs = newDotExpr(newIdentNode("a"), newIdentNode("float"))
            op_rhs = newDotExpr(newIdentNode("b"), newIdentNode("float"))
            assig_lhs = newIdentNode("result")
            assig_rhs = newNimNode(nnkPar).add(infix(op_lhs, op, op_rhs))
        body.add(newAssignment(assig_lhs, assig_rhs))
            
        procComp.add(body)
        result.add(procComp)

    # Full names
    fullnames = initTable[TComposition, string](nextPowerOfTwo(len(compos)))
    for a in aliases_config:
        fullnames.add(a.compo, a.name)
        echo a.compo, a.name
    for c in compos:
        if not fullnames.hasKey(c):
            fullnames.add(c, get_fullname(c, config))

    # Display functions ($)
    # TODO refactor to avoid the double call to get_uname()
    for f in pairs(fullnames):
        var
            uname = get_uname(f.key, config, uname_config)
            procDisp = newNimNode(nnkProcDef)
            name = newNimNode(nnkPostfix)

        if uname == uname_config.prefix:
            uname = uname_config.prefix & uname_config.nodim

        name.add(newIdentNode("*")) # TODO refactor outside
        name.add(newNimNode(nnkAccQuoted).add(newIdentNode("$")))
        procDisp.add(name)

        procDisp.add(newEmptyNode())
        procDisp.add(newEmptyNode())
        var formalParams = newNimNode(nnkFormalParams)
        echo "*", treeRepr(formalParams)
        formalParams.add(newIdentNode("string"))
        echo "**", treeRepr(formalParams)
        echo f.key, uname
        echo treeRepr(formalParams)
        formalParams.add(newIdentDefs(newIdentNode("a"), newIdentNode(uname)))
        echo "#", treeRepr(formalParams)
        procDisp.add(formalParams)
        echo "@"
        procDisp.add(newEmptyNode())
        procDisp.add(newEmptyNode())
        var 
            body = newNimNode(nnkStmtList)
            assig_lhs = newIdentNode("result")
            assig_rhs = newCall("formatFloat",
                                newDotExpr(newIdentNode("a"), newIdentNode("float")),
                                newIdentNode("ffDefault"),
                                newIntLitNode(0))
        body.add(newAssignment(assig_lhs, assig_rhs))
        body.add(newAssignment(newIdentNode("result"), newCall("add", newIdentNode("result"),newStrLitNode(f.val))))
        #echo treeRepr(body)

        procDisp.add(body)
        #echo treeRepr(procDisp)
        result.add(procDisp)
    #echo treeRepr result
