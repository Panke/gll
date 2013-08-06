import probat.all;
import std.stdio;
version(test_gll) 
{
void main(string[] argv)
{
    writeln("möööp");
    auto runner = new StandAloneTestRunner(argv);
    runner.run();
}
}
