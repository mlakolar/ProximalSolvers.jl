# Round-two checks; extract only pure bound definitions, never execute the replay writer.
include("<RUN>/agents/A/lib.jl")
src=read("<RUN>/scripts/orch_d2_gated.jl",String)
include_string(Main,src[findfirst("function Pup",src).start:findfirst("\nrecs =",src).start-1],"gated_bound_definitions")
setprecision(BigFloat,512)
function check_bounds()
    rng=Xoshiro(18112026); badlo=badup=accepted=increases=0; nchecks=0
    for k in 1:2000
        n=rand(rng,1:15); p=rand(rng,1:20)
        scale=ldexp(1.,rand(rng,-530:400))
        X=randn(rng,n,p); y=scale*randn(rng,n); b=scale*randn(rng,p)
        k%4==0 && (y=X*b)
        k%5==0 && (b=zeros(p))
        l=ldexp(0.5,rand(rng,-50:50)); lo,hi=PS._level_brackets(l)
        P=Pbig(X,y,l,b); L=Plo(X,y,lo,b); U=Pup(X,y,hi,b)
        badlo += !(big(L)<=P); badup += !(P<=big(U)); nchecks+=1
        newb=scale*randn(rng,p); Un=Pup(X,y,hi,newb)
        if Un<L
            accepted+=1; increases+=Pbig(X,y,l,newb)>=P
        end
    end
    println("Plo/Pup checks: ",nchecks," lower violations=",badlo," upper violations=",badup," accepted changes=",accepted," nondecreases=",increases)
    # Round-one false-decrease example must now be rejected.
    X=ones(1,2);y=[1.];A=2.0^40;b=[A,1-A];newb=zeros(2);l=(1-1e-5)/(2A-1)
    L=Plo(X,y,l,b);U=Pup(X,y,l,newb)
    println("Round-one example: Plo(x0)=",L," Pup(new)=",U," gate accepts=",U<L)
    # Newly revised infeasibility branch: consistent support, but off-support slab impossible.
    X=[1. 2.];y=[1.];b=[1.,0.];d=[-2.,1.];l=.1
    G(d)=.5norm(X*d)^2+l*d[1]+l*abs(d[2])
    println("Consistent-support counterexample: theta from support=",l," offsupport correlation=",2l," > lambda=",l," null(X_S) dimension=0 Xd=",X*d," G(kd)=",[G(k*d) for k in [1.,10.,100.]])
end
check_bounds()
