module dlint.app;

import core.stdc.stdio;

import std.algorithm.searching : startsWith;
import std.typecons : Tuple;

import dmd.astcodegen;
import dmd.dmodule : Module;
import dmd.frontend;
import dmd.globals;

import dlint.checks.undocumented;

Tuple!(Module, "module_", Diagnostics, "diagnostics") parseModule(AST = ASTCodegen)(
	const(char)[] fileName)
{
	import dmd.root.file : File, FileBuffer;

	import dmd.globals : Loc, global;
	import dmd.parse : Parser;
	import dmd.identifier : Identifier;
	import dmd.tokens : TOK;

	import std.path : baseName, stripExtension;
	import std.string : toStringz;
	import std.typecons : tuple;

	auto id = Identifier.idPool(fileName.baseName.stripExtension);
	auto m = new Module(fileName, id, 1, 0);

	m.read(Loc.initial);

	m.parseModule!AST();

	Diagnostics diagnostics = {
		errors: global.errors,
		warnings: global.warnings
	};

	return typeof(return)(m, diagnostics);
}

void main(string[] args)
{
	initDMD;
	global.params.showColumns = true;

	import std.algorithm : each;
	findImportPaths.each!addImport;

	import std.file;

	Module[] modules;

	foreach (arg; args[1..$])
	{
		if (arg.startsWith("-"))
		{
			switch (arg)
			{
				case "-unittest":
				case "-d":
				case "-dw":
				case "-de":
					break; // ignore
				default:
					if (arg.startsWith("-I"))
						addImport(arg[2 .. $]);
					else
						throw new Exception("Unknown switch: " ~ arg);
			}
			continue;
		}

		debug(dlint) printf("# Loading %.*s\n",
			cast(int)arg.length, arg.ptr);

		auto t = parseModule(arg);

		assert(!t.diagnostics.hasErrors);
		assert(!t.diagnostics.hasWarnings);

		modules ~= t.module_;
	}

	auto linter = new UndocumentedLinter;

	foreach (m; modules)
	{
		debug(dlint) printf("# Processing %s\n",
			m.srcfile.toChars());

		m.fullSemantic;
		m.accept(linter);
	}
}
