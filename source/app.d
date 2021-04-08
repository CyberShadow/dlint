module dlint.app;

import core.internal.traits : Parameters;
import core.stdc.stdio;

import std.algorithm.searching : startsWith;

import dmd.astcodegen;
import dmd.frontend;
import dmd.visitor;

extern(C++) final class Linter : SemanticTimeTransitiveVisitor
{
	alias visit = typeof(super).visit;

	alias AST = ASTCodegen;
	debug(dlint) int depth;

	// We do this because the TransitiveVisitor does not forward
	// visit(FooDeclaration) to visit(Declaration)
	static foreach (overload; __traits(getOverloads, Visitor, "visit"))
		override void visit(Parameters!overload[0] d)
		{
			debug(dlint) { depth++; scope(success) depth--; }

			// We do this because e.g. Declaration and
			// AggregateDeclaration are unrelated types which both
			// have a `visibility` field (and their common ancestor
			// does not have a `visibility` field).
			static if (is(typeof(d) == AST.Import)
				|| is(typeof(d) == AST.CompoundStatement))
			{
				// Does not need to be documented or traversed
				debug(dlint) printf("%*s# %s: Skipping %s %s\n",
					depth, "".ptr,
					d.loc.toChars(),
					typeof(d).stringof.ptr,
					d.toChars());
			}
			else
			static if (is(typeof(d.visibility) : AST.Visibility))
			{
				// Should be documented, and traversed
				debug(dlint) printf("%*s# %s: %s %s %d\n",
					depth, "".ptr,
					d.loc.toChars(),
					typeof(d).stringof.ptr,
					d.toChars(),
					d.visibility.kind);
				if (d.visibility.kind != AST.Visibility.Kind.undefined &&
					d.visibility.kind < AST.Visibility.Kind.public_)
					return;

				// Skip compiler-generated declarations
				static if (is(typeof(d.generated) : bool))
					if (d.generated)
						return;
				// Needed e.g. for __xpostblit
				if (d.ident && d.ident.toString().startsWith("__"))
					return;

				static if (is(typeof(d) == AST.VisibilityDeclaration))
				{
					// Has visibility, but cannot be documented
					debug(dlint) printf("%*s# (skipping)\n",
						depth, "".ptr);
				}
				else
					visitDeclaration(typeof(d).stringof.ptr, d);
				super.visit(d);
			}
			else
			{
				const(char)* loc;
				static if (is(typeof(d.loc)))
					loc = d.loc.toChars();
				else
					loc = "-";
				debug(dlint) printf("%*s# %s: Visiting unknown %s %s\n",
					depth, "".ptr,
					loc,
					typeof(d).stringof.ptr,
					d.toChars());
				super.visit(d);
			}
		}

	void visitDeclaration(const(char)* type, AST.Dsymbol d)
	{
		if (d.comment)
			return;

		printf("%s: Undocumented public declaration: %s `%s`\n",
			d.loc.toChars(),
			type, d.toChars());
	}
}

import std.typecons : Tuple;
import dmd.dmodule : Module;

Tuple!(Module, "module_", Diagnostics, "diagnostics") parseModule(AST = ASTCodegen)(
	const(char)[] fileName,
	const(char)[] code = null)
{
	import dmd.root.file : File, FileBuffer;
	import dmd.root.filename : FileName;

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
