import tables, os, times, strtabs, sets
import compiler / [options, commands, modules, sem,
  passes, passaux, msgs,
  sigmatch, ast,
  idents, modulegraphs, prefixmatches, lineinfos, cmdlinehelper,
  pathutils, rod, idgen, condsyms]

var required = initHashSet[string]()

proc writeDepsFile(g: ModuleGraph) =
  for m in g.modules:
    if m != nil:
      required.incl toFullPath(g.config, m.position.FileIndex)
  for k in g.inclToMod.keys:
    if g.getModule(k).isNil:  # don't repeat includes which are also modules
      required.incl toFullPath(g.config, k)

var output = ""
proc myLog(s: string) =
  #echo s
  output &= s & "\n"

proc errorHook(config: ConfigRef, info: TLineInfo, msg: string, severity: Severity) {.gcsafe.} =
  if severity == Error:
    echo output
    echo msg

proc mainCommand(graph: ModuleGraph) =
  let conf = graph.config
  conf.cmd = cmdGenDepend
  setupModuleCache(graph)
  conf.searchPaths.add(conf.libpath)
  for directory in walkDirRec($conf.libpath, yieldFilter = {pcDir}):
    conf.searchPaths.add(directory.AbsoluteDir)
  registerPass graph, verbosePass
  registerPass graph, semPass
  wantMainModule(conf)

  conf.writeLnHook = myLog
  # A bug in Nim prevents this from being useful..
  #conf.structuredErrorHook = errorHook
  compileProject(graph)
  writeDepsFile(graph)

if paramCount() < 2:
  quit "Usage: builder <nim standard library path> [<relative path of module in library> ...]"
try:
  for i in 2..paramCount():
    proc mockCmdLine(pass: TCmdLinePass, cmd: string; conf: ConfigRef) =
      conf.libpath = AbsoluteDir unixToNativePath(paramStr(1))
      conf.projectName = unixToNativePath(conf.libpath.string / paramStr(i).string)

    let
      cache = newIdentCache()
      conf = newConfigRef()
      self = NimProg(
        suggestMode: true,
        processCmdLine: mockCmdLine,
        mainCommand: mainCommand
      )

    self.initDefinesProg(conf, "nim_compiler")
    conf.symbols["nimscript"] = "true"
    self.processCmdLineAndProjectPath(conf)
    discard self.loadConfigsAndRunMainCommand(cache, conf)
except:
  echo "Something went wrong:"
  echo output

removeDir("minilib")
createDir("minilib")
for module in required:
  let name = "minilib" / module[paramStr(1).len..^1]
  createDir name.splitPath.head
  copyFile module, name
