import probat.all;

version(test_gll) 
{
void main(string[] argv)
{
    auto runner = new StandAloneTestRunner(argv);
    runner.run();
}
}
