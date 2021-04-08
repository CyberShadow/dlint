// Special language constructs which should not trigger a positive.

// public imports
public import object;

// compiler-generated methods
private struct WithCopyCtor { this(this) { } }
struct bad01
{
	WithCopyCtor c;
}

// lambdas in function declarations

/// documented!
void fun(alias pred=(a, b) => a is b)() {}
