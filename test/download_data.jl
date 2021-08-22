using TropicalCycloneRecords

atlantic_url ="https://www.nhc.noaa.gov/data/hurdat/hurdat2-1851-2019-042820.txt"
data = Dict{String,Dict{T,N} where T where N}()
res = Tropical.read_hurdat(atlantic_url,true)
Tropical.hurdat_to_dictionary(res,data)
