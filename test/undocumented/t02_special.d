// Special language constructs which should not trigger a positive.

// --- public imports
public import object;

// --- compiler-generated methods
private struct WithCopyCtor { this(this) { } }
struct bad01
{
	WithCopyCtor c;
}

// --- lambdas in function declarations

/// documented!
void fun(alias pred=(a, b) => a is b)() {}

// --- aliases for overloads

/// documented!
class Good1
{
	/// documented!
	void good1() {}
}

/// also documented!
class Good2 : Good1
{
	/// also documented!
	alias good1 = Good1.good1;

	/// documented!
	void good1(int) {}
}

// --- nested classes

/// documented!
class Good3
{
	/// also documented!
	class Good4
	{
	}
}
