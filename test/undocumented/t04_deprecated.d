// Deprecated symbols are exempt from being documented.

void bad1() {}
deprecated void good2() {}
deprecated struct good3
{
	void good4() {}
}

deprecated("foo")
template good5()
{
	int good5() {}
}

deprecated
template good6()
{
	int good6() {}
}

deprecated void good7()()
{
}
