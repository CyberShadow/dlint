module dlint.checks.undocumented;

import core.internal.traits : Parameters;
import core.stdc.stdio;

import std.algorithm.searching : startsWith;

import dmd.astcodegen;
import dmd.visitor;

extern(C++) final class UndocumentedLinter : SemanticTimeTransitiveVisitor
{
	alias visit = typeof(super).visit;

	alias AST = ASTCodegen;
	debug(dlint) int depth;
	AST.Visibility.Kind currentVisibility = AST.Visibility.Kind.public_;

	// We do this because the TransitiveVisitor does not forward
	// visit(FooDeclaration) to visit(Declaration)
	static foreach (overload; __traits(getOverloads, Visitor, "visit"))
		override void visit(Parameters!overload[0] d)
		{
			debug(dlint) { depth++; scope(success) depth--; }

			static if (is(typeof(d.storage_class)))
				if (d.storage_class & AST.STC.deprecated_)
					return;

			static if (is(typeof(d) == AST.Import)
				|| is(typeof(d) == AST.CompoundStatement)
				|| is(typeof(d) == AST.FuncLiteralDeclaration))
			{
				// Does not need to be documented or traversed
				debug(dlint) printf("%*s# %s: Skipping %s %s\n",
					depth, "".ptr,
					d.loc.toChars(),
					typeof(d).stringof.ptr,
					d.toChars());
			}
			else
			// We do this because e.g. Declaration and
			// AggregateDeclaration are unrelated types which both
			// have a `visibility` field (and their common ancestor
			// does not have a `visibility` field).
			static if (is(typeof(d.visibility) : AST.Visibility))
			{
				auto visibility = d.visibility.kind;
				if (visibility == AST.Visibility.Kind.undefined)
					visibility = currentVisibility;

				static if (is(typeof(d) == AST.VisibilityDeclaration))
				{
					// Has visibility, but cannot be documented;
					// may contain public members
					debug(dlint) printf("%*s# %s: Silently descending into %s %s\n",
						depth, "".ptr,
						d.loc.toChars(),
						typeof(d).stringof.ptr,
						d.toChars());
				}
				else
				{
					// Should be documented, and traversed
					debug(dlint) printf("%*s# %s: %s %s %d\n",
						depth, "".ptr,
						d.loc.toChars(),
						typeof(d).stringof.ptr,
						d.toChars(),
						d.visibility.kind);

					if (visibility < AST.Visibility.Kind.public_)
						return;

					// Some declarations need to be public even though
					// they should not be (e.g. if they are exposed
					// through public aliases).  Apply the same
					// convention as seen in many other languages
					// without visibility as a language feature, and
					// treat variable starting with "_" as private.
					// (This will also include compiler-generated
					// symbols, such as __xpostblit).
					static if (!is(typeof(d) == AST.CtorDeclaration))
						if (d.ident && d.ident.toString().startsWith("_"))
							return;

					// Skip compiler-generated declarations
					static if (is(typeof(d.generated) : bool))
						if (d.generated)
							return;
					if (!d.loc.isValid())
						return;

					visitDeclaration(typeof(d).stringof.ptr, d);
				}

				static if (is(typeof(d) == AST.AliasDeclaration))
				{
					// Should be documented, but must not be traversed
					debug(dlint) printf("%*s#(not traversing!)\n",
						depth, "".ptr,
						d.loc.toChars(),
						typeof(d).stringof.ptr,
						d.toChars());
				}
				else
				{
					auto lastVisibility = currentVisibility;
					currentVisibility = visibility;
					scope(success) currentVisibility = lastVisibility;

					super.visit(d);
				}
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