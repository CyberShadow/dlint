void bad01() {}

private void good01() {}

private
{
	void good02() {}
}

/// documented!
void good03() {}

void good04() {} /// ditto

struct bad1
{
	void bad11() {}
private:
	void good12() {}
}

private struct good2
{
	void good21() {}
public:
	void good22() {}
}

void bad3()
{
	int good31;
}

struct bad4(T)
{
	void bad41() {}
private:
	void good42() {}
}

