include("makeStretchData.jl")
include("../../../src/utils.jl")

using PlotlyJS, SeisIO, SeisNoise, JLD2

foname="verificationData.jld2"

finame_xcorr="/Users/jared/SCECintern2019/data/xcorrs/BPnetwork_Jan03_xcorrs.2003.1.T00:00:00.jld2"
dataset_xcorr="2003.1.T00:00:00/BP.CCRB..BP1.BP.EADB..BP1"
xcf=jldopen(finame_xcorr)
real_xcorr=xcf[dataset_xcorr]
save=true
plot=false

if size(real_xcorr.corr)[2]>1 stack!(real_xcorr, allstack=true) end

dvVlist = collect(-0.03:0.0001:0.03)
noiselist = collect(0.0:0.01:0.1)

if save
    f=jldopen(foname, "a+")
    f["info/dvVlist"] = dvVlist
    f["info/noiselist"] = noiselist
end

dampedSinParams = Dict( "A"    => 1.0,
                        "ω"    => 0.75,
                        "ϕ"    => 0.0,
                        "λ"    => 0.025,
                        "dt"   => 0.05,
                        "η"    => 0.0,
                        "t0"   => 0.0,
                        "npts" => 4001)

sincParams = Dict( "A"    => 1.0,
                   "ω"    => 0.1,
                   "ϕ"    => 0.0,
                   "dt"   => 0.05,
                   "t0"   => 0.0,
                   "npts" => 4001)

rickerParams = Dict( "f"     => 0.25,
                     "dt"    => 0.05,
                     "npr"   => 4001,
                     "npts"  => 4001)

lags = -real_xcorr.maxlag:1/real_xcorr.fs:real_xcorr.maxlag

for dvV in dvVlist
    for noiselvl in noiselist
        # Example of damped sinusoid generation, stretching, and noise addition
        signal1_ds, t_ds = generateSignal("dampedSinusoid", params=dampedSinParams)
        normalize!(signal1_ds)
        signal2_ds, st_ds = stretchData(signal1_ds, dampedSinParams["dt"], dvV, n=noiselvl)

        addNoise!(signal1_ds, noiselvl)
        addNoise!(signal2_ds, noiselvl, seed=664739)

        # Example of ricker wavelet generation and convolution with random reflectivity
        # series, stretching, and noise addition
        signal1_rc, t_rc = generateSignal("ricker", sparse=100, params=rickerParams)
        normalize!(signal1_rc)
        signal2_rc, st_rc = stretchData(signal1_rc, rickerParams["dt"], dvV, n=noiselvl)

        addNoise!(signal1_rc, noiselvl)
        addNoise!(signal2_rc, noiselvl, seed=664739)

        # Example of stretching real cross-correlations
        xcorr = real_xcorr.corr[:,1]
        normalize!(xcorr)
        stretch_xcorr, st_xcorr = stretchData(xcorr, 1/real_xcorr.fs, dvV, starttime=-real_xcorr.maxlag, stloc=0.0, n=noiselvl)

        addNoise!(xcorr, noiselvl)
        addNoise!(stretch_xcorr, noiselvl, seed=664739)

        if save
            f["dampedSinusoid/$dvV.$noiselvl"] = [signal1_ds, signal2_ds]
            f["rickerConv/$dvV.$noiselvl"] = [signal1_rc, signal2_rc]
            f["realData/$dvV.$noiselvl"] = [xcorr, stretch_xcorr]
        end

        if plot
            p1 = PlotlyJS.Plot([PlotlyJS.scatter(;x=t_ds, y=signal1_ds, name="Unstretched"),
                                PlotlyJS.scatter(;x=t_ds, y=signal2_ds, name="Stretched $(dvV*(-100))%")])
            p2 = PlotlyJS.Plot([PlotlyJS.scatter(;x=t_rc, y=signal1_rc, name="Unstretched"),
                                PlotlyJS.scatter(;x=t_rc, y=signal2_rc, name="Stretched $(dvV*(-100))%")])
            p3 = PlotlyJS.Plot([PlotlyJS.scatter(;x=lags, y=xcorr, name="Unstretched"),
                                PlotlyJS.scatter(;x=lags, y=stretch_xcorr, name="Stretched $(dvV*(-100))%")])
            plots = [p1, p2, p3]
            p=PlotlyJS.plot(plots)
            display(p)
            readline()
        end
    end
end
if save close(f) end
close(xcf)
