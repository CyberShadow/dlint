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
	bool inEponymous;

	// We do this because the TransitiveVisitor does not forward
	// visit(FooDeclaration) to visit(Declaration)
	static foreach (overload; __traits(getOverloads, Visitor, "visit"))
		override void visit(Parameters!overload[0] d)
		{
			debug(dlint) { depth++; scope(success) depth--; }

			void log()(string s)
			{
				const(char)* loc;
				static if (is(typeof(d.loc)))
					loc = d.loc.toChars();
				else
					loc = "-";
				debug(dlint) printf("%*s# %s: %.*s %s %s\n",
					depth, "".ptr,
					loc,
					cast(int)s.length, s.ptr,
					typeof(d).stringof.ptr,
					d.toChars());
			}

			bool ignoreCurrent;
			if (inEponymous)
			{
				inEponymous = false;
				ignoreCurrent = true;
			}

			if (isDeprecated(d))
				return log("Skipping deprecated");

			static if (is(typeof(d) == AST.TemplateDeclaration))
				if (d.onemember)
				{
					/// DMD moves the "deprecated" attribute on the
					/// inner symbol for eponymous templates.
					if (isDeprecated(d.onemember))
						return log("Skipping deprecated eponymous");

					log("Diving inside eponymous");
					if (!ignoreCurrent)
						if (!checkThing(d)) // outer
							return;
					inEponymous = true;
					d.onemember.accept(this);
					return;
				}

			static if (is(typeof(d) == AST.Import)
				|| is(typeof(d) == AST.CompoundStatement)
				|| is(typeof(d) == AST.FuncLiteralDeclaration)
				|| is(typeof(d) == AST.ThisDeclaration)
				|| is(typeof(d) == AST.DeprecatedDeclaration))
			{
				// Does not need to be documented or traversed
				debug(dlint) log("Skipping");
			}
			else
			// We do this because e.g. Declaration and
			// AggregateDeclaration are unrelated types which both
			// have a `visibility` field (and their common ancestor
			// does not have a `visibility` field).
			static if (is(typeof(d.visibility) : AST.Visibility))
			{
				auto visibility = currentVisibility;

				static if (is(typeof(d) == AST.VisibilityDeclaration))
				{
					// Has visibility, but cannot be documented;
					// may contain public members
					debug(dlint) printf("%*s# %s: Silently descending into %s %s %d\n",
						depth, "".ptr,
						d.loc.toChars(),
						typeof(d).stringof.ptr,
						d.toChars(),
						d.visibility.kind);
					visibility = d.visibility.kind;
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

					if (!ignoreCurrent)
						if (!checkThing(d))
							return;
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
				log("Visiting unknown");
				super.visit(d);
			}
		}

	bool isDeprecated(T)(T d)
	{
		static if (is(typeof(d.storage_class)))
			if (d.storage_class & AST.STC.deprecated_)
				return true;
		static if (is(typeof(d.stc)))
			if (d.stc & AST.STC.deprecated_)
				return true;
		static if (is(typeof(d) : AST.Dsymbol))
			if (d.isDeprecated())
				return true;
		return false;
	}

	bool checkThing(T)(T d)
	{
		if (currentVisibility < AST.Visibility.Kind.public_)
			return false;

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
				return false;

		// Skip compiler-generated declarations
		static if (is(typeof(d.generated) : bool))
			if (d.generated)
				return false;
		if (!d.loc.isValid())
			return false;

		checkDsymbol(typeof(d).stringof.ptr, d);
		return true;
	}

	void checkDsymbol(const(char)* type, AST.Dsymbol d)
	{
		if (d.comment)
			return;

		printf("%s: Undocumented public declaration: %s `%s`\n",
			d.loc.toChars(),
			type, d.toChars());
	}
}
