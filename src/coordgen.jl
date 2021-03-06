#
# This file is a part of MolecularGraph.jl
# Licensed under the MIT License http://opensource.org/licenses/MIT
#

export
    coordgen!

using coordgenlibs_jll


function coordgen!(mol::GraphMol)
    minmol = ccall((:getSketcherMinimizer, libcoordgen), Ptr{Cvoid}, ())
    atoms = Ptr{Cvoid}[]
    bonds = Ptr{Cvoid}[]

    # Atoms
    for nattr in nodeattrs(mol)
        atom = ccall(
            (:setAtom, libcoordgen), Ptr{Cvoid},
            (Ptr{Cvoid}, Int), minmol, atomnumber(nattr)
        )
        push!(atoms, atom)
    end

    # Bonds
    for (i, (u, v)) in enumerate(edgesiter(mol))
        bond = ccall(
            (:setBond, libcoordgen), Ptr{Cvoid},
            (Ptr{Cvoid}, Ptr{Cvoid}, Ptr{Cvoid}, Int),
            minmol, atoms[u], atoms[v], edgeattr(mol, i).order
        )
        push!(bonds, bond)
    end

    ccall(
        (:assignBondsAndNeighbors, libcoordgen), Cvoid,
        (Ptr{Cvoid},), minmol
    )

    # Stereocenter
    for i in 1:nodecount(mol)
        nattr = nodeattr(mol, i)
        nattr.stereo in (:clockwise, :anticlockwise) || continue
        direction = nattr.stereo === :clockwise
        if degree(mol, i) == 4
            f, s, t, _ = sort(collect(adjacencies(mol, i)))
        elseif degree(mol, i) == 3
            f, s, t = sort(collect(adjacencies(mol, i)))
            if i < f || (i > s && i < t) # implicit H is the 1st or 3rd
                direction = !direction
            end
        else
            continue
        end
        ccall(
            (:setStereoCenter, libcoordgen), Cvoid,
            (Ptr{Cvoid}, Ptr{Cvoid}, Ptr{Cvoid}, Ptr{Cvoid}, Int),
            atoms[i], atoms[f], atoms[s], atoms[t], direction
        )
    end

    # StereoBond
    for (i, (n1, n2)) in enumerate(edgesiter(mol))
        eattr = edgeattr(mol, i)
        eattr.stereo in (:cis, :trans) || continue
        iscis = eattr.stereo === :cis
        u = sort([adj for adj in adjacencies(mol, n1) if adj != n2])[1]
        v = sort([adj for adj in adjacencies(mol, n2) if adj != n1])[1]
        ccall(
            (:setStereoBond, libcoordgen), Cvoid,
            (Ptr{Cvoid}, Ptr{Cvoid}, Ptr{Cvoid}, Int),
            bonds[i], atoms[u], atoms[v], iscis
        )
    end

    # Optimize
    ccall(
        (:runGenerateCoordinates, libcoordgen), Cvoid,
        (Ptr{Cvoid},), minmol
    )

    # Output
    coords = zeros(Float64, nodecount(mol), 2)
    for i in 1:nodecount(mol)
        px = ccall(
            (:getAtomX, libcoordgen), Float32, (Ptr{Cvoid},), atoms[i])
        py = ccall(
            (:getAtomY, libcoordgen), Float32, (Ptr{Cvoid},), atoms[i])
        coords[i, :] = [px, py]
    end
    notation = Int[]
    for i in 1:edgecount(mol)
        hasstereo = ccall(
            (:hasStereochemistryDisplay, libcoordgen), Bool,
            (Ptr{Cvoid},), bonds[i])
        if !hasstereo
            push!(notation, 0)
            continue
        end
        iswedge = ccall(
            (:isWedge, libcoordgen), Bool, (Ptr{Cvoid},), bonds[i])
        isrev = ccall(
            (:isReversed, libcoordgen), Bool, (Ptr{Cvoid},), bonds[i])
        push!(notation, iswedge ? 1 : 6)
        u, v = mol.edges[i]
        if isrev
            mol.edges[i] = (v, u)
        end
    end
    mol.cache[:coords2d] = coords
    mol.cache[:coordgenbond] = notation
end
