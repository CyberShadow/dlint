module dlint.app;

import dmd.frontend;

import dmd.permissivevisitor;
import dmd.transitivevisitor;

import dmd.visitor;
import dmd.dsymbol;
import dmd.declaration;
import dmd.astcodegen;

import core.internal.traits;
import core.stdc.stdio;

extern(C++) final class Linter : SemanticTimeTransitiveVisitor
{
	alias visit = typeof(super).visit;

	alias AST = ASTCodegen;

	// We do this because the TransitiveVisitor does not forward
	// visit(FooDeclaration) to visit(Declaration)
	static foreach (overload; __traits(getOverloads, Visitor, "visit"))
		override void visit(Parameters!overload[0] d)
		{
			// We do this because e.g. Declaration and
			// AggregateDeclaration are unrelated types which both
			// have a `visibility` field (and their common ancestor
			// does not have a `visibility` field).
			static if (is(typeof(d.visibility) : AST.Visibility))
			{
				debug(dlint) printf("%s %s %d\n", typeof(d).stringof.ptr, d.toChars(), d.visibility.kind);
				if (d.visibility.kind != AST.Visibility.Kind.undefined &&
					d.visibility.kind < AST.Visibility.Kind.public_)
					return;

				visitDeclaration(d);
			}
			else
			{
				debug(dlint) printf("%s %s\n", typeof(d).stringof.ptr, d.toChars());
			}
			super.visit(d);
		}

	void visitDeclaration(Dsymbol d)
	{
		if (d.comment)
			return;

		printf("%s: Undocumented public declaration: %s %s\n",
			d.loc.toChars(),
			typeof(d).stringof.ptr, d.toChars());
	}
}

import dmd.root.filename;
import dmd.dmodule;
import std.algorithm.searching;
import std.typecons;

Tuple!(Module, "module_", Diagnostics, "diagnostics") parseModule(AST = ASTCodegen)(
	const(char)[] fileName,
	const(char)[] code = null)
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
	auto m = new Module(fileName, id, 0, 0);
	m.docfile = FileName("/dev/null");

	if (code is null)
		m.read(Loc.initial);
	else
	{
		File.ReadResult readResult = {
			success: true,
			buffer: FileBuffer(cast(ubyte[]) code.dup ~ '\0')
		};

		m.loadSourceBuffer(Loc.initial, readResult);
	}

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

	import std.algorithm : each;
	findImportPaths.each!addImport;

	import std.file;

	foreach (arg; args[1..$])
	{
		if (arg.startsWith("-"))
		{
			if (arg.startsWith("-I"))
				addImport(arg[2 .. $]);
			else
				throw new Exception("Unknown switch: " ~ arg);
			continue;
		}

		auto fn = arg;
		auto input = readText(fn);

		auto t = parseModule(fn, input);

		assert(!t.diagnostics.hasErrors);
		assert(!t.diagnostics.hasWarnings);

		t.module_.fullSemantic;
		auto linter = new Linter;
		t.module_.accept(linter);
	}
}
