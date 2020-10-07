using Tropical
using Documenter

makedocs(;
    modules=[Tropical],
    authors="Argel Ramírez Reyes <argel.ramirez@gmail.com> and contributors",
    repo="https://github.com/aramirezreyes/Tropical.jl/blob/{commit}{path}#L{line}",
    sitename="Tropical.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://aramirezreyes.github.io/Tropical.jl",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
)

deploydocs(;
    repo="github.com/aramirezreyes/Tropical.jl",
)
