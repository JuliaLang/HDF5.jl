function Base.show(io::IO, fid::File)
    if isvalid(fid)
        print(io, "HDF5.File: ", fid.filename)
    else
        print(io, "HDF5.File: (closed) ", fid.filename)
    end
end

function Base.show(io::IO, g::Group)
    if isvalid(g)
        print(io, "HDF5.Group: ", name(g), " (file: ", g.file.filename, ")")
    else
        print(io, "HDF5.Group: (invalid)")
    end
end

function Base.show(io::IO, prop::Properties)
    if prop.class == H5P_DEFAULT
        print(io, "HDF5.Properties: default class")
    elseif isvalid(prop)
        print(io, "HDF5.Properties: ", h5p_get_class_name(prop.class), " class")
    else
        print(io, "HDF5.Properties: (invalid)")
    end
end

function Base.show(io::IO, dset::Dataset)
    if isvalid(dset)
        print(io, "HDF5.Dataset: ", name(dset), " (file: ", dset.file.filename, " xfer_mode: ", dset.xfer.id, ")")
    else
        print(io, "HDF5.Dataset: (invalid)")
    end
end

function Base.show(io::IO, attr::Attribute)
    if isvalid(attr)
        print(io, "HDF5.Attribute: ", name(attr))
    else
        print(io, "HDF5.Attribute: (invalid)")
    end
end
function Base.show(io::IO, attr::Attributes)
    print(io, "Attributes of ", attr.parent)
end

function Base.show(io::IO, dtype::Datatype)
    print(io, "HDF5.Datatype: ")
    if isvalid(dtype)
        print(io, h5lt_dtype_to_text(dtype))
    else
        # Note that h5i_is_valid returns `false` on the built-in datatypes (e.g.
        # H5T_NATIVE_INT), apparently because they have refcounts of 0 yet are always
        # valid. Just temporarily turn off error printing and try the call to probe if
        # dtype is valid since H5LTdtype_to_text special-cases all of the built-in types
        # internally.
        old_func, old_client_data = h5e_get_auto(H5E_DEFAULT)
        h5e_set_auto(H5E_DEFAULT, C_NULL, C_NULL)
        local text
        try
            text = h5lt_dtype_to_text(dtype)
        catch
            text = "(invalid)"
        finally
            h5e_set_auto(H5E_DEFAULT, old_func, old_client_data)
        end
        print(io, text)
    end
end

"""
    SHOW_TREE = Ref{Bool}(true)

Configurable option to control whether the default `show` for HDF5 objects is printed
using `show_tree` or not.
"""
const SHOW_TREE = Ref{Bool}(true)
"""
    SHOW_TREE_ICONS = Ref{Bool}(true)

Configurable option to control whether emoji icons (`true`) or a plain-text annotation
(`false`) is used to indicate the object type by `show_tree`.
"""
const SHOW_TREE_ICONS = Ref{Bool}(true)

function Base.show(io::IO, ::MIME"text/plain", obj::Union{File,Group,Dataset,Attributes,Attribute})
    if SHOW_TREE[]
        show_tree(io, obj)
    else
        show(io, obj)
    end
end

function _tree_icon(obj)
    if SHOW_TREE_ICONS[]
        return obj isa Attribute ? "🏷️ " :
               obj isa Group ? "📂 " :
               obj isa Dataset ? "🔢 " :
               obj isa Datatype ? "📄 " :
               obj isa File ? "🗂️ " :
               "❓ "
    else
        return obj isa Attribute ? "[A] " :
               obj isa Group ? "[G]" :
               obj isa Dataset ? "[D] " :
               obj isa Datatype ? "[T] " :
               obj isa File ? "[F] " :
               "[?] "
    end
end
_tree_icon(obj::Attributes) = _tree_icon(obj.parent)

_tree_head(io::IO, obj) = println(io, _tree_icon(obj), obj)
_tree_head(io::IO, obj::Datatype) = println(io, _tree_icon(obj), "HDF5.Datatype: ", name(obj))

function _tree_children(parent::Union{File, Group}, attributes::Bool)
    names = keys(parent)
    objs  = Union{Object, Attribute}[parent[n] for n in names]
    if attributes
        attrn = keys(attrs(parent))
        attro = Union{Object, Attribute}[attrs(parent)[n] for n in attrn]
        names = append!(attrn, names)
        objs  = append!(attro, objs)
    end
    return (names, objs)
end
function _tree_children(parent::Dataset, attributes::Bool)
    names = String[]
    objs = Union{Object, Attribute}[parent[n] for n in names]
    if attributes
        attrn = keys(attrs(parent))
        attro = Union{Object, Attribute}[attrs(parent)[n] for n in attrn]
        names = append!(attrn, names)
        objs  = append!(attro, objs)
    end
    return (names, objs)
end
function _tree_children(parent::Attributes, attributes::Bool)
    names = keys(parent)
    objs  = Union{Object,Attribute}[parent[n] for n in names]
    return (names, objs)
end
function _tree_children(parent::Union{Attribute, Datatype}, attributes::Bool)
    # TODO: add our own implementation of much of what h5lt_dtype_to_text() does?
    return (String[], Union{Object, Attribute}[])
end

function show_tree(io::IO, obj::Union{File,Group,Dataset,Datatype,Attributes,Attribute}, indent::String="";
                   attributes::Bool = true)
    isempty(indent) && _tree_head(io, obj)
    !isvalid(obj) && return

    names, children = _tree_children(obj, attributes)
    nchildren = length(children)
    for ii in 1:nchildren
        name = names[ii]
        child  = children[ii]

        islast = ii == nchildren
        icon = _tree_icon(child)
        println(io, indent, islast ? "└─ " : "├─ ", icon, name)

        nextindent = indent * (islast ? "   " : "│  ")
        show_tree(io, child, nextindent; attributes = attributes)
    end
    return nothing
end
show_tree(obj; kws...) = show_tree(stdout, obj; kws...)
