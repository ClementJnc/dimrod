import lib_example

#Test section
var
    a = 5.0.Tm
    b = 4.2.Tkg
    c : Tm_kgv1
    d = 3.Tm
    e = 43.Tnodim
    t = 1.Ts
    g : TN
c = a / b
echo c
echo a+d
echo a-d
echo a/d
echo a*e
echo b * a / t / t
g = 8.7.TN
echo b * a / t / t + g


echo "Min of ",a, " and ", d, " is ", min(a, d)
