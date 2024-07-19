unsigned long long factorial(int n)
{
    int c;
    unsigned long long result = 1;

    for (c = 1; c <= n; c++){
        result = result * c;

    }


    return result;
}
