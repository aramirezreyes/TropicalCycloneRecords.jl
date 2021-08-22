"""
    read_hurdat(path,flag)
Get a hurdat url or filepath and downloads dataset from said resource. It returns the content of the downloaded csv as an array of arrays
"""

function read_hurdat(path,flag)
    @info "Started downloading and parsing HURDAT data"
    if flag
        res = get(path)
        res = decode(res.body,"UTF-8")
        res = split(res,"\n")
        res = replace.(res," " => "")
        res = split.(res,",")
        #@info res
    else
    end
    @info "Finished downloading and parsing HURDAT data"
    return res
end

function hurdat_to_dictionary!(content,data_dict,override_basin=false)
    @info "Started processing HURDAT2 data"
    is_header(line) = first(line[1]) ∈ ('A','C','E')
    current_id = "" #This will be re_defined in the header
    basin = ""
    for line in content
        if length(line) < 2
            continue
        end
        if is_header(line)
            #@info line
            basin = "north_atlantic"
            if first(line[1]) == "C"
                basin = "east_pacific"
            elseif first(line[1]) == "E"
                basin = "east_pacific"
            end
            if override_basin == true
                basin = "all"
            end
            data_dict[line[1]] = Dict(
                "id"=>line[1],
                "operational_id"=>"",
                "name"=>line[2],
                "year"=>parse(Int,line[1][nextind(line[1],0,5):end]),
                "season"=>parse(Int,line[1][nextind(line[1],0,5):end]),
                "basin"=>basin,
                "source_info"=>"NHC Hurricane Database",
                "source" => "hurdat"
            )
            current_id = line[1]
            data_dict[current_id]["date"]      = Union{Missing,DateTime}[]
            data_dict[current_id]["extra_obs"] = Union{Missing,Bool}[]
            data_dict[current_id]["special"]   = Union{Missing,String}[]
            data_dict[current_id]["type"]      = Union{Missing,String}[]
            data_dict[current_id]["lat"]       = Union{Missing,Float64}[]
            data_dict[current_id]["lon"]       = Union{Missing,Float64}[]
            data_dict[current_id]["vmax"]      = Union{Missing,Int}[]
            data_dict[current_id]["mslp"]      = Union{Missing,Int}[]
            data_dict[current_id]["wmo_basin"] = Union{Missing,String}[]
            data_dict[current_id]["ace"]       = 0.0
        else
            
            yyyymmdd,HHMM,special,storm_type,lat,lon,vmax,mslp = line[begin:9]

            date = DateTime(string(yyyymmdd,HHMM),"yyyymmddHHMM")
            
            if occursin('N',lat)
                lat = parse(Float64,split(lat,"N")[1])
            elseif occursin('S',lat)
                lat = -1.0*parse(Float64,split(lat,"S")[1])
            end
            if occursin('W',lon)
                lon = -1.0*parse(Float64,split(lon,"W")[1])
            elseif occursin('E',lon)
                lon = parse(Float64,split(lon,"E")[1])
            end
            # Handle missing data
            vmax = parse(Int,vmax) >= 0 ? parse(Int,vmax) : missing
            mslp = parse(Int,mslp) >= 800 ? parse(Int,mslp) : missing 
            #Handel off-hour obs
            push!(data_dict[current_id]["extra_obs"], HHMM ∉ ["0000","0600","1200","1800"])
            #Fix storm type for cross-dateline storms
            storm_type = replace(storm_type,"ST" => "HU")
            storm_type = replace(storm_type,"TY" => "HU")

            #Add data to data_dict

            push!(data_dict[current_id]["date"],date)
            push!(data_dict[current_id]["special"],special)
            push!(data_dict[current_id]["type"],storm_type)
            push!(data_dict[current_id]["lat"],lat)
            push!(data_dict[current_id]["lon"],lon)
            push!(data_dict[current_id]["vmax"],vmax)
            push!(data_dict[current_id]["mslp"],mslp)

            if basin == "north_atlantic"
                push!(data_dict[current_id]["wmo_basin"],"north_atlantic")
            elseif basin == "east_pacific" & lon > 0.0
                push!(data_dict[current_id]["wmo_basin"],"west_pacific")
            elseif basin == "east_pacific" & lon <= 0.0
                push!(data_dict[current_id]["wmo_basin"],"east_pacific")
            else
                push!(data_dict[current_id]["wmo_basin"],"west_pacific")
            end

            #Calculate ACE & append to storm total
            if !ismissing(vmax)
                ace = (10 ^ (-4)) * (vmax ^ 2)
                if (HHMM ∈ ["0000","0600","1200","1800"]) & (storm_type ∈ ["SS","TS","HU"])
                    data_dict[current_id]["ace"] += round(ace; digits=4)
                end
            end
            
        end
    end
    
    #Account for operationally unnamed storms
    current_year = 0
    current_year_id = 1
    
    for storm in keys(data_dict)
        storm_data = data_dict[storm]
        storm_name = storm_data["name"]
        storm_year = storm_data["year"]
        storm_vmax = storm_data["vmax"]
        storm_id = storm_data["id"]
        
        max_wnd = all(ismissing.(storm_vmax)) ? missing : maximum(skipmissing(storm_vmax))
                #Fix current year
        if current_year == 0
            current_year = storm_year
        else
            if storm_year != current_year
                current_year = storm_year
                current_year_id = 1
                #special fix for 1992 in the Atlantic
                if (current_year == 1992) & (data_dict[current_id]["basin"] == "north_atlantic")
                    current_year_id = 2
                end
                
            end
        end
        
        #Estimate operational storm ID (which sometimes differs from HURDAT2 ID) ## TODO check if type can be constrained
        blocked_list = Union{Missing,String}[]
        potential_tcs = Union{Missing,String}["AL102017"]
        increment_but_pass = Union{Missing,String}[]
        
        if storm_name == "UNNAMED" &&  !ismissing(max_wnd) && (max_wnd >= 34) && (storm_id ∉ blocked_list)
            if storm_id ∈ increment_but_pass
                current_year_id += 1
            end
            continue
        elseif storm_id[begin:nextind(storm_id,1)] == "CP"
            continue                
        else
            #Skip potential TCs
            if string(storm_id[begin:nextind(storm_id,1)],current_year_id,storm_year) ∈ potential_tcs
                current_year_id += 1
            end
            data_dict[storm]["operational_id"] = string(storm_id[begin:nextind(storm_id,1)],current_year_id,storm_year)
            current_year_id += 1
        end
        
        
        #Swap operational storm IDs, if necessary
        swap_list = ["EP101994","EP111994"]
        swap_pair = ["EP111994","EP101994"]
        
        if data_dict[storm]["operational_id"] ∈ swap_list
            @info swapping
            swap_idx = findfirst(isequal(data_dict[storm]["operational_id"]),swap_list)
            data_dict[key]["operational_id"] = swap_pair[swap_idx]
        end
    end

    @info "Completed processing HURDAT2 data"
    
    return data_dict
end

function read_and_process_hurdat(atlantic_url ="https://www.nhc.noaa.gov/data/hurdat/hurdat2-1851-2019-042820.txt",flag = true,override_basin=false)
    data_dict = Dict{String,Dict{T,N} where T where N}()
    res = Tropical.read_hurdat(atlantic_url,flag)
    hurdat_data = hurdat_to_dictionary!(res,data_dict,override_basin)
end
