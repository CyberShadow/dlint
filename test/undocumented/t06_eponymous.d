// Eponymous templates

template Bad1()
{
	int good11() {};

	struct good12 {}

	struct Bad1
	{
		int bad11;
	}
}

/// documented!
struct good1(T)
{
}

private void good2()() {}


/// documented!
template good1()
{
	void good1()() {}
}
