struct PickAxisArray{P,N}
  parent::P
  stride::NTuple{N,Int}
end
function PickAxisArray(p,indmask)
  #@show indmask
  #@show ndims(p)
  @assert sum(indmask) == ndims(p)
  strides = zeros(Int,length(indmask))
  s = 1
  j = 1
  for i=1:length(indmask)
    if indmask[i]
      strides[i]=s
      s = s * size(p,j)
      j=j+1
    else
      strides[i]=0
    end
  end
  pstrides = ntuple(i->strides[i],length(strides))
  PickAxisArray{typeof(p),length(strides)}(p,pstrides)
end
function Base.getindex(a::PickAxisArray{P,N},i::Vararg{Int,N}) where {P,N}
    ilin = sum(map((i,s)->(i-1)*s,i,a.stride))+1
    a.parent[ilin]
end
function Base.getindex(a::PickAxisArray{P,N},i::NTuple{N,Int}) where {P,N}
    ilin = sum(map((i,s)->(i-1)*s,i,a.stride))+1
    a.parent[ilin]
end
Base.getindex(a::PickAxisArray,i::CartesianIndex) = a[i.I]

import ESDL.DAT: DATConfig
struct CubeIterator{R,ART,ARTBC,LAX,ILAX,S}
    dc::DATConfig
    r::R
    inars::ART
    inarsBC::ARTBC
    loopaxes::LAX
end
Base.IteratorSize(::Type{<:CubeIterator})=Base.HasLength()
Base.IteratorEltype(::Type{<:CubeIterator})=Base.HasEltype()
Base.eltype(i::Type{<:CubeIterator{A,B,C,D,E,F}}) where {A,B,C,D,E,F} = F
# function splitIterator(ci::CubeIterator)
#   t=typeof(ci)
#   map(ci.r) do r
#     dcnew = deepcopy(ci.dc)
#     inars = getproperty.(dcnew.incubes,:handle)
#     inarsbc = map(dcnew.incubes) do ic
#       allax = falses(length(dc.LoopAxes))
#       allax[icnew.loopinds].=true
#       PickAxisArray(icnew.handle,allax)
#     end
#     loopaxes=deepcopy(ci.loopaxes)
#     t(dcnew,r,inars,inarsbc,loopaxes)
#   end
# end

# function cubeeltypes(::Type{<:CubeIterator{<:Any,ART}}) where ART
#   allt = gettupletypes.(gettupletypes(ART))
#   map(i->Union{eltype(i[1]),Missing},allt)
# end
# gettupletypes(::Type{Tuple{A}}) where A = (A,)
# gettupletypes(::Type{Tuple{A,B}}) where {A,B} = (A,B)
# gettupletypes(::Type{Tuple{A,B,C}}) where {A,B,C} = (A,B,C)
# gettupletypes(::Type{Tuple{A,B,C,D}}) where {A,B,C,D} = (A,B,C,D)
# gettupletypes(::Type{Tuple{A,B,C,D,E}}) where {A,B,C,D,E} = (A,B,C,D,E)
# gettupletypes(::Type{Tuple{A,B,C,D,E,F}}) where {A,B,C,D,E,F} = (A,B,C,D,E,F)
# axtypes(::Type{<:CubeIterator{A,B,C,D,E}}) where {A,B,C,D,E} = axtype.(gettupletypes(D))
# axtype(::Type{<:CubeAxis{T}}) where T = T
getrownames(t::Type{<:CubeIterator}) = fieldnames(t)
getncubes(::Type{<:CubeIterator{A,B}}) where {A,B} = tuplelen(B)
tuplelen(::Type{<:NTuple{N,<:Any}}) where N=N
axsym(ax::CubeAxis{<:Any,S}) where S = S

lift64(::Type{Float32})=Float64
lift64(::Type{Int32})=Int64
lift64(T)=T

function CubeIterator(s,dc,r;varnames::Tuple=ntuple(i->Symbol("x$i"),length(dc.incubes)),include_loopvars=())
    loopaxes = ntuple(i->dc.LoopAxes[i],length(dc.LoopAxes))
    inars = getproperty.(dc.incubes,:handle)
    length(varnames) == length(dc.incubes) || error("Supplied $(length(varnames)) varnames and $(length(dc.incubes)) cubes.")
    rt = map(c->Union{eltype(c.handle[1]),Missing},dc.incubes)
    inarsbc = map(dc.incubes) do ic
      allax = falses(length(dc.LoopAxes))
      allax[ic.loopinds].=true
      PickAxisArray(ic.handle,allax)
    end
    et = map(i->Union{lift64(eltype(i[1])),Missing},inars)
    if !isempty(include_loopvars)
      ilax = map(i->findAxis(i,collect(loopaxes)),include_loopvars)
      any(isequal(nothing),ilax) && error("Axis not found in cubes")
      et=(et...,map(i->eltype(loopaxes[i]),ilax)...)
    else
      ilax=()
    end
    CubeIterator{typeof(r),typeof(inars),typeof(inarsbc),typeof(loopaxes),ilax,s{et...}}(dc,r,inars,inarsbc,loopaxes)
end
function Base.show(io::IO,ci::CubeIterator{<:Any,<:Any,<:Any,<:Any,<:Any,E}) where E
  print(io,"Datacube iterator with ", length(ci), " elements with fields: ",E)
end
Base.length(ci::CubeIterator)=prod(length.(ci.loopaxes))
function Base.iterate(ci::CubeIterator)
    rnow,blockstate = iterate(ci.r)
    updateinars(ci.dc,rnow)
    innerinds = CartesianIndices(length.(rnow))
    indnow, innerstate = iterate(innerinds)
    offs = map(i->first(i)-1,rnow)
    getrow(ci,ci.inarsBC,indnow,offs),(rnow=rnow,blockstate=blockstate,innerinds = innerinds, innerstate=innerstate)
end
function Base.iterate(ci::CubeIterator,s)
    t1 = iterate(s.innerinds,s.innerstate)
    N = tuplelen(eltype(ci.r))
    if t1 == nothing
        t2 = iterate(ci.r,s.blockstate)
        if t2 == nothing
            return nothing
        else
            rnow = t2[1]
            blockstate = t2[2]
            updateinars(ci.dc,rnow)
            innerinds = CartesianIndices(length.(rnow))
            indnow,innerstate = iterate(innerinds)

        end
    else
        rnow, blockstate = s.rnow, s.blockstate
        innerinds = s.innerinds
        indnow, innerstate = iterate(innerinds,s.innerstate)
    end
    offs = map(i->first(i)-1,rnow)
    getrow(ci,ci.inarsBC,indnow,offs),(rnow=rnow::NTuple{N,UnitRange{Int64}},
      blockstate=blockstate::Int64,
      innerinds=innerinds::CartesianIndices{N,NTuple{N,Base.OneTo{Int64}}},
      innerstate=innerstate::CartesianIndex{N})
end
abstract type CubeRow
end
#Base.getproperty(s::CubeRow,v::Symbol)=Base.getfield(s,v)
abstract type CubeRowAx<:CubeRow
end
# function Base.getproperty(s::T,v::Symbol) where T<:CubeRowAx
#   if v in fieldnames(T)
#     getfield(s,v)
#   else
#     ax = getfield(s,:axes)
#     ind = getfield(s,:i)
#     i = findfirst(i->axsym(i)==v,ax)
#     ax[i].values[ind.I[i]]
#   end
# end

# @noinline function getrow(ci::CubeIterator{R,ART,ARTBC,LAX,ILAX,RN,RT},inarsBC,indnow)::NamedTuple{RN,RT} where {R,ART,ARTBC,LAX,ILAX,RN,RT}
#   axvals = map(i->ci.loopaxes[i].values[indnow.I[i]],ILAX)
#   cvals  = map(i->i[indnow],inarsBC)
#   allvals::RT = (axvals...,cvals...)
#   #NamedTuple{RN,RT}(axvals...,cvals...)
#   NamedTuple{RN,RT}(allvals)
# end
function getrow(ci::CubeIterator{<:Any,<:Any,<:Any,<:Any,ILAX,S},inarsBC,indnow,offs) where {ILAX,S<:CubeRowAx}
   #inds = map(i->indnow.I[i],ILAX)
   #axvals = map((i,indnow)->ci.loopaxes[i][indnow],ILAX,inds)
   axvalsall = map((ax,i,o)->ax.values[i+o],ci.loopaxes,indnow.I,offs)
   axvals = map(i->axvalsall[i],ILAX)
   cvals  = map(i->i[indnow],inarsBC)
   S(cvals...,axvals...)
end
function getrow(ci::CubeIterator{<:Any,<:Any,<:Any,<:Any,<:Any,S},inarsBC,indnow,offs) where S<:CubeRow
   cvals  = map(i->i[indnow],inarsBC)
   S(cvals...)
end

# @generated function getrow(ci::CI,inarsBC,indnow) where CI
#     rn = getrownames(CI)
#     nc = getncubes(CI)
#     exlist = [:($(rn[i]) = inarsBC[$ir][indnow]) for (ir,i) = enumerate((length(rn)-nc+1):length(rn))]
#     if length(rn)>nc
#       exlist2 = [:($(rn[i]) = ci.loopaxes[$i].values[indnow.I[$i]]) for i=1:(length(rn)-nc)]
#       exlist = [exlist2;exlist]
#     end
#     Expr(:(::),Expr(:tuple,exlist...),eltype(ci))
# end

function Base.show(io::IO,s::CubeRow)
  print(io,"Cube Row: ")
  for n in propertynames(s)
    print(io,string(n), "=",getproperty(s,n)," ")
  end
end
function Base.show(io::IO,s::CubeRowAx)
  print(io,"Cube Row: ")
  for n in propertynames(s)
    print(io,string(n), "=",getproperty(s,n)," ")
  end
end
function Base.show(io::IO,s::Type{<:CubeRow})
  foreach(fieldnames(s)) do fn
    print(io,fn,"::",fieldtype(s,fn),", ")
  end
end
function Base.iterate(s::CubeRow,state=1)
  allnames = propertynames(s)
  if state<=length(allnames)
    (getproperty(s,allnames[state]),state+1)
  else
    nothing
  end
end


import DataStructures: OrderedDict
export @CubeTable
"""
    @CubeTable input_vars...

Macro to turn a DataCube object into an iterable table. Takes a list of as arguments,
specified either by a cube variable name alone or by a `name=cube` expression. For example
`@CubeTable cube1 country=cube2` would generate a Table with the entries `cube1` and `country`,
where `cube1` contains the values of `cube1` and `country` the values of `cube2`. The cubes
are matched and broadcasted along their axes like in `mapCube`.

In addition, one can specify
`axes=(ax1,ax2...)` when one wants to include the values of certain xes in the table. For example
the command `@CubeTable tair=cube1 axes=(lon,lat,time)` would produce an iterator over a data structure
with entries `tair`, `lon`, `lat` and `time`.

Lastly there is an option to specify which axis shall be the fastest changing when iterating over the cube.
For example `@CubeTable cube1 fastest=time` will ensure that the iterator will always loop over consecutive
time steps of the same location.
"""
macro CubeTable(cubes...)
  axargs=[]
  fastloopvar=""
  clist = OrderedDict{Any,Any}()
  for c in cubes
    if isa(c,Symbol)
      clist[esc(c)]=esc(c)
    elseif isa(c,Expr) && c.head==:(=)
      if c.args[1]==:axes
        axdef = c.args[2]
        if isa(axdef,Symbol)
          push!(axargs,axdef)
        else
          append!(axargs,axdef.args)
        end
      elseif c.args[1]==:fastest
        fastloopvar=c.args[2]
      else
        clist[esc(c.args[1])]=esc(c.args[2])
      end
    end
  end
  allcubes = collect(values(clist))
  allnames = collect(keys(clist))
  s = esc(gensym())
  theparams = Expr(:curly,s,[Symbol("T$i") for i=1:length(clist)]...)
  fields = Expr(:block,[Expr(:(::),fn,Symbol("T$i")) for (i,fn) in enumerate(allnames)]...)
  #pn = Expr(:tuple,map(i->QuoteNode(i.args[1]),allnames)...)
  if !isempty(axargs)
    foreach(axargs) do ax
      as = Symbol(ax)
      push!(theparams.args,Symbol("AX$as"))
      push!(fields.args,:($(esc(as))::$(Symbol("AX$as"))))
      #push!(pn.args,as)
    end
    supert=:CubeRowAx
  else
    supert=:CubeRow
  end
  quote
    struct $theparams <: $supert
      $fields
    end
    #Base.propertynames(s::$s)=$pn
    _CubeTable($s,$(allcubes...),include_axes=$(Expr(:tuple,string.(axargs)...)), varnames=$(Expr(:tuple,QuoteNode.(allnames)...)),fastvar=$(QuoteNode(fastloopvar)))
  end
end


function _CubeTable(thetype,c::AbstractCubeData...;include_axes=(),varnames=varnames,fastvar="")
  inax=nothing
  if isempty(string(fastvar))
    indims = map(i->InDims(),c)
  else
    indims = map(c) do i
      iax = findAxis(string(fastvar),i)
      if iax > 0
        inax = caxes(i)[iax]
        InDims(string(fastvar))
      else
        InDims()
      end
    end
  end
  inaxname = inax==nothing ? nothing : axname(inax)
  axnames = map(i->axname.(caxes(i)),c)
  allvars = union(axnames...)
  allnums = collect(1:length(allvars))
  perms = map(axnames) do v
    map(i->findfirst(isequal(i),allvars),v)
  end
  c2 = map(perms,c) do p,cube
    if issorted(p)
      cube
    else
      pp=sortperm(p)
      pp = ntuple(i->pp[i],length(pp))
      permutedims(cube,pp)
    end
  end

    configiter = mapCube(identity,c2,debug=true,indims=indims,outdims=());
    if inax !== nothing
    linax = length(inax)
    pushfirst!(configiter.LoopAxes,inax)
    pushfirst!(configiter.loopCacheSize,linax)
    foreach(configiter.incubes) do ic1
      if !isempty(ic1.axesSmall)
        empty!(ic1.axesSmall)
        map!(i->i+1,ic1.loopinds,ic1.loopinds)
        pushfirst!(ic1.loopinds,1)
      else
        map!(i->i+1,ic1.loopinds,ic1.loopinds)
      end
    end
  end
  r = collect(distributeLoopRanges(totuple(configiter.loopCacheSize),totuple(map(length,configiter.LoopAxes)),getchunkoffsets(configiter)))
  ci = CubeIterator(thetype,configiter,r, include_loopvars=include_axes,varnames=varnames)
end


import Tables
Tables.istable(::Type{<:CubeIterator}) = true
Tables.rowaccess(::Type{<:CubeIterator}) = true
Tables.rows(x::CubeIterator) = x
Tables.schema(x::CubeIterator) = Tables.schema(typeof(x))
Tables.schema(x::Type{<:CubeIterator}) = Tables.Schema(fieldnames(eltype(x)),map(s->fieldtype(eltype(x),s),fieldnames(eltype(x))))
