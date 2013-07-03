#' @include utils.R
NULL

## valid rank designations on NCBI
.ranks  <- c("root","superkingdom","kingdom","subkingdom","superphylum",
             "phylum","subphylum","superclass","class","subclass","infraclass",
             "superorder","order","suborder","parvorder","infraorder",
             "superfamily","family","subfamily","tribe","subtribe","genus",
             "subgenus","species group","species subgroup","species","subspecies",
             "varietas","forma","no rank")


# Class definition - Taxon -----------------------------------------------


#' Retrieve records from the NCBI Taxonomy database.
#'
#' \dQuote{Taxon} is an S4 class that provides a container for records
#' retrieved from the NCBI Taxonomy database.
#' It is extended by the classes \dQuote{Taxon_minimal} and \dQuote{Lineage}
#' with three slots \emph{TaxId}, \emph{ScientificName}, and \emph{Rank},
#' and by class \dQuote{Taxon_full}, with the additional slots
#' \emph{ParentTaxId}, \emph{OtherName}, \emph{Authority},
#' \emph{TypeMaterial}, and \emph{Lineage}.
#'  
#' @rdname Taxon
#' @export
#' @classHierarchy
#' @classMethods 
setClass("Taxon",
         representation(shared = "environment"),
         prototype(shared = new.env(parent=emptyenv())))


## extract the shared database environment from objects
#' @importFrom rmisc shared
setMethod("shared", "Taxon", function(x, value = NULL) {
  if (is.null(value))
    x@shared
  else
    tryCatch(get(value, envir=x@shared, inherits=FALSE),
             error = function (e) NULL)
})


# Class definition - Taxon_minimal ---------------------------------------


.valid_TaxonMinimal <- function (object) {
  errors <- character()
  if (!all(grepl("^\\d+$", getTaxId(object))) &&
        !all(is.na(getTaxId(object)))) {
    msg <- "TaxIds must contain only digits or NA"
    errors <- c(errors, msg)
  }
  
  if (!all(getRank(object) %in% .ranks) &&
        !all(is.na(getRank(object)))) {
    msg <- paste0("Invalid rank designation ",
                  sQuote(getRank(object)[!getRank(object)%in%.ranks]))
    errors <- c(errors, msg) 
  }
  
  if (length(errors) == 0) 
    TRUE
  else
    errors
}


#' @rdname Taxon
#' @export
#' @classHierarchy
#' @classMethods
setClass("Taxon_minimal",
         contains="Taxon",
         representation(TaxId = "character",
                        ScientificName = "character",
                        Rank = "character"),
         prototype(TaxId = NA_character_,
                   ScientificName = NA_character_,
                   Rank = NA_character_),
         validity = .valid_TaxonMinimal)


#' @title Taxon accessors
#' 
#' @description
#' Access the slots of \linkS4class{Taxon} or \linkS4class{TaxonList}
#' instances.
#' 
#' @param x A \linkS4class{Taxon} or \linkS4class{TaxonList}.
#' @param ... Further arguments passed on to methods. 
#' @rdname Taxon-accessors
#' @export
#' @genericMethods
setGeneric("getTaxId", function(x, ...) standardGeneric("getTaxId"))
setMethod("getTaxId", "Taxon_minimal", function (x, use.names = TRUE) {
  if (use.names)
    setNames(x@TaxId, nm=getScientificName(x))
  else
    x@TaxId
})


#' @rdname Taxon-accessors
#' @export
#' @genericMethods
setGeneric("getScientificName", function(x, ...) standardGeneric("getScientificName"))
setMethod("getScientificName", "Taxon_minimal", function (x)  x@ScientificName )


#' @rdname Taxon-accessors
#' @export
#' @genericMethods
setGeneric("getRank", function(x, ...) standardGeneric("getRank"))
setMethod("getRank", "Taxon_minimal", function(x) x@Rank)


setMethod("is.na", "Taxon", function (x) {
  is.na(getTaxId(x)) && is.na(getScientificName(x)) && is.na(getRank(x))
})


# Class-definition - Lineage ---------------------------------------------


.valid_Lineage <- function (object) {
  errors <- character()
  n <- length(getTaxId(object, use.names = FALSE))
  lengths <- c(length(getScientificName(object)), length(getRank(object)))
  
  if (any(lengths != n)) {
    msg <- paste0("Inconsistent lengths: TaxId = ", n, 
                  ", ScientificName = ", lengths[1], 
                  ", Rank = ", lengths[2])
    errors <- c(errors, msg)
  }
  
  if (length(errors) == 0) 
    TRUE
  else
    errors
}


#' @rdname Taxon
#' @export
#' @classHierarchy
#' @classMethods 
setClass("Lineage", contains="Taxon_minimal", validity = .valid_Lineage)


Lineage <- function (..., shared = new.env(parent=emptyenv())) {
  listData <- list(...)
  if (all_empty(listData)) {
    new('Lineage', shared = shared)
  }
  else {
    if (length(listData) == 1L && ( is.list(listData[[1L]]) || is.matrix(listData[[1L]] ))) 
      listData <- listData[[1L]]
    if (all(vapply(listData, is, "Taxon", FUN.VALUE=logical(1)))) {
      new('Lineage', shared = shared,
          TaxId = vapply(listData, getTaxId, character(1)),
          ScientificName = vapply(listData, getScientificName, character(1)),
          Rank = vapply(listData, getRank, character(1)))
    }
    else if (all(colnames(listData) %in% c("tax_id", "tax_name", "rank"))) {
      new('Lineage', shared = shared,
          TaxId = listData[, "tax_id"] %||% NA_character_,
          ScientificName = listData[, "tax_name"] %||% NA_character_,
          Rank = listData[, "rank"] %||% NA_character_)
    }
    else {
      stop("All elements in '...' must be 'Taxon' objects or a named list ",
           "containing 'tax_id', 'tax_name', and 'rank'.")
    }
  }
}


setMethod("[", "Lineage",
          function(x, i, j, ... , drop=FALSE) {
            if (!missing(j))
              stop("invalid subsetting")
            if (!missing(i)) {
              if (is.character(i))
                stop("Cannot subset a Lineage object by character")
              
              value <- list(...)$value
              if (is.null(value)) {
                x@TaxId <- x@TaxId[i] %||% NA_character_
                x@ScientificName <- x@ScientificName[i] %||% NA_character_
                x@Rank <- x@Rank[i] %||% NA_character_
              } 
              else {
                x <- slot(x, value)[i] %||% NA_character_
              }
            }
            if (drop && !is.null(value))
              data.frame(TaxId = x@TaxId, ScientificName = x@ScientificName,
                         Rank = x@Rank, stringsAsFactors=FALSE)
            else x
          })


.show_Lineage <- function (x, width = getOption("width"), ellipsis = " ... ") {
  ellipsize(paste0(getScientificName(x), collapse="; "), width = width, ellipsis = ellipsis)
}
setMethod("show", "Lineage",
          function (object) {
            lo <- length(getTaxId(object))
            showme <- sprintf("A %s of length %s\n%s", sQuote(class(object)), lo,
                              .show_Lineage(object))
            cat(showme, sep="")
          })


#' Extract taxa from a lineage by their rank
#'
#' Valid rank designations are:
#' superkingdom, kingdom, subkingdom, superphylum,
#' phylum, subphylum, superclass, class, subclass, infraclass, 
#' superorder, order, suborder, parvorder, infraorder, 
#' superfamily, family, subfamily, tribe, subtribe, genus, 
#' subgenus, species group, species subgroup, species, subspecies, 
#' varietas, and forma.
#'
#' @param x A \code{\linkS4class{Taxon}, \code{\linkS4class{TaxonList}},
#' \code{\linkS4class{Lineage}}, or \code{\linkS4class{LineageList}} object.
#' @param rank One of the valid ranks for NCBI taxonomies (see Details).
#' @param value One of \code{NULL}, \sQuote{TaxId}, or \sQuote{ScientificName}.
#' If \code{NULL}, \code{Taxon} objects are returned, otherwise a character
#' vector of TaxIds or scientific names, respectively.
#'
#' @rdname getByRank
#' @export
#' @genericMethods
setGeneric("getByRank", function(x, rank, value = NULL, ...) standardGeneric("getByRank"))
setMethod("getByRank", "Lineage", function (x, rank, value = NULL, drop = FALSE) {
  rank <- match.arg(rank, ncbi:::.ranks)
  i <- which(getRank(x) == rank)
  
  if (!is.null(value)) {
    value <- match.arg(value, c("TaxId", "ScientificName"))
    x[i, value = value, drop = drop]
  }
  else {
    new_taxon_db(taxid=x[i, value = "TaxId"], shared=shared(x))
  }
})


# Class-definition - Taxon_full ------------------------------------------


#' @slot TaxId The Taxonomy Identifier, a stable unique identifier for
#' each taxon in the NCBI Taxonomy database.
#' @slot ScientificName The unique scientific name of the taxon.
#' @slot Rank The taxonomic rank of the taxon.
#'  
#' @slot ParentTaxId The Taxonomy Identifier of the parental taxon.
#' @slot OtherName A named character vector holding synonyms
#' or GenBankSynonyms.
#' @slot Authority
#' @slot TypeMaterial
#' @slot Lineage
#' 
#' @rdname Taxon
#' @export
#' @classHierarchy
#' @classMethods
setClass("Taxon_full",
         contains = "Taxon_minimal",
         representation(ParentTaxId = "character",
                        OtherName = "character",
                        Authority = "character",
                        TypeMaterial = "character",
                        Lineage = "Lineage"),
         prototype(ParentTaxId = NA_character_,
                   OtherName = NA_character_,
                   Authority = NA_character_,
                   TypeMaterial = NA_character_,
                   Lineage = new("Lineage")))


.show_Taxon <- function (x, width = getOption("width"), ellipsis = "...") {
  ellipsize(sprintf("%s (%s; %s)", getTaxId(x, FALSE), getScientificName(x),
                    getRank(x)), width = width, ellipsis = ellipsis)
}
setMethod("show", "Taxon",
          function (object) {
            showme <- .show_Taxon(object)
            cat(showme, sep="\n")
            if (is(object, "Taxon_full")) {
              lin <- .show_Lineage(getLineage(object),
                                   width = getOption("width") - 10) %||% NA_character_
              cat(sprintf("Lineage: %s\n", lin), sep="")
            }
          })


# Accessors --------------------------------------------------------------


#' @rdname Taxon-accessors
#' @export
#' @genericMethods
setGeneric("getParentTaxId", function (x, ...) standardGeneric("getParentTaxId"))
setMethod("getParentTaxId", "Taxon_full", function(x) x@ParentTaxId)


#' @rdname Taxon-accessors
#' @export
#' @genericMethods
setGeneric("getOtherName", function (x, ...) standardGeneric("getOtherName"))
setMethod("getOtherName", "Taxon_full", function(x) x@OtherName)


#' @rdname Taxon-accessors
#' @export
#' @genericMethods
setGeneric("getAuthority", function (x, ...) standardGeneric("getAuthority"))
setMethod("getAuthority", "Taxon_full", function(x) x@Authority)


#' @rdname Taxon-accessors
#' @export
#' @genericMethods
setGeneric("getLineage", function(x, ...) standardGeneric("getLineage"))
setMethod("getLineage", "Taxon_full", function(x) x@Lineage)


#' @rdname Taxon-accessors
#' @export
#' @genericMethods
setMethod("getByRank", "Taxon_full", function (x, rank, value = NULL) {
  getByRank(getLineage(x), rank=rank, value=value)
})


# Constructors -----------------------------------------------------------


#' @details
#' See the documentation at 
#' \href{http://www.ncbi.nlm.nih.gov/books/NBK21100/}{NCBI}
#' for more information.
#' 
#' @param taxid \sQuote{taxids} or a valid NCBI search term.
#' @param rettype Which type of data should be retrieved? Full records
#' (default: \code{NULL}) or an \sQuote{uilist}. 
#' @param retmax Maximal number of records to be retrieved (default: 25).
#' @param parse Should the retrieved data be parsed?
#' @param ... Parameters passed on to the underlying \code{\link{efetch}}
#' query.
#'
#' @return An \linkS4class{XMLInternalDocument} or if parsed a
#'  \linkS4class{taxon} or \linkS4class{TaxonList} instance.
#' @rdname Taxon
#' @export
#' @autoImports
taxon <- function (taxid, rettype = NULL, retmax = 25, parse = TRUE, ...) {
  if (missing(taxid)) {
    return(new("Taxon_full"))
  }
  
  if (is(taxid, "esearch")) {
    if (database(taxid) != 'taxonomy')
      stop("Database ", sQuote(database(taxid)), " not supported")
    if (!has_webenv(taxid))
      taxid <- idList(taxid)
  }
  
  args <- getArgs(id=taxid, db="taxonomy", rettype, retmax, ...)
  response <- fetch_records(args, 500)
  if (parse) {
    switch(args$rettype %|null|% "xml",
           xml = parseTaxon(response),
           uilist = parseUilist(response),
           response)
  } else {
    response
  }
}


#' @param taxid TaxId
#' @param shared Shared environment containing a connection to taxon.db
#' and (optionally) geneid.db
#' @param full Taxon_minimal or Taxon_full
#' @keywords internal
new_taxon_db <- function(taxid, shared, full = TRUE) {
  assert_that(!is.null(shared$taxonDBcon))
  if (full)
    tx <- lapply(taxid, dbGetTaxon, db=shared)
  else
    tx <- lapply(taxid, dbGetTaxonMinimal, db=shared)
  
  if (length(tx) == 1)
    tx[[1]]
  else
    TaxonList(tx, shared=shared)
}


#' @param taxid A vector of valid NCBI Taxonomy Identifiers.
#' @param dbPath Path to a valid Taxon.db 
#' @param full if \code{FALSE} a minimal taxonomic description is extracted
#' (TaxId, ScientificName, Rank).
#'
#' @return A \linkS4class{Taxon} or \linkS4class{TaxonList} instance.
#' @rdname Taxon
#' @export
taxonDB <- function (taxid, dbPath=NULL, full=TRUE) {
  if (missing(taxid)) {
    return( new("Taxon_full") )
  }
  shared <- new.env(parent=emptyenv())
  shared$taxonDBcon <- taxonDBConnect(dbPath)
  new_taxon_db(taxid, shared, full=full)
}


#' @param geneid GeneId (GI-number)
#' @param shared Shared environment containing a connection to taxon.db
#' and (optionally) geneid.db
#' @param full Taxon_minimal or Taxon_full
#' @keywords internal
new_taxon_by_geneid <- function(geneid, shared, full=TRUE) {
  assert_that(!is.null(shared$taxonDBcon))
  assert_that(!is.null(shared$geneidDBcon))
  if (length(getTaxidByGeneID(shared, 2)) == 0)
    stop("'genes' table is empty. Run 'createTaxonDB()' setting 'with_geneid = TRUE'")
  
  if (full)
    tx <- lapply(geneid, dbGetTaxonByGeneID, db=shared)
  else
    tx <- lapply(geneid, dbGetTaxonMinimalByGeneID, db=shared)
  
  if (length(tx) == 1)
    tx[[1]]
  else
    TaxonList(tx, shared=shared)
}


#' @param geneid A vector of valid NCBI Gene Identifiers.
#' @param dbPath 
#' @param full if \code{FALSE} a minimal taxonomic description is extracted
#' (TaxId, ScientificName, Rank).
#'
#' @return A \linkS4class{Taxon} or \linkS4class{TaxonList} instance.
#' @rdname Taxon
#' @export
taxonByGeneID <- function (geneid, dbPath=NULL, full=TRUE) {
  if (missing(geneid)) {
    return( new("Taxon_full") )
  }
  
  shared <- new.env(parent=emptyenv())
  shared$taxonDBcon <- taxonDBConnect(dbPath)
  shared$geneidDBcon <- geneidDBConnect(dbPath)
  new_taxon_by_geneid(geneid, shared, full=full)
}


# Parser -----------------------------------------------------------------


#' @export
#' @autoImports
parseTaxon <- function (taxaSet = response) {
  
  if (is(taxaSet, "efetch")) {
    taxaSet <- content(taxaSet)
  }
  catchEFetchError(taxaSet)
  if (!is(taxaSet, "XMLInternalDocument")) {
    return(taxaSet)
  }
  taxaSet <- getNodeSet(xmlRoot(taxaSet), '//TaxaSet/Taxon')
  if (all_empty(taxaSet)) {
    stop("No 'TaxaSet' provided")
  }
  
  tx <- base::lapply(taxaSet, function (taxon) {
    # taxon <- xmlDoc(taxaSet[[1]])
    taxon <- xmlDoc(taxon)
    taxMin <- new("Taxon_minimal",
                  TaxId = xvalue(taxon, '/Taxon/TaxId'),
                  ScientificName = xvalue(taxon, '/Taxon/ScientificName'),
                  Rank = xvalue(taxon, '/Taxon/Rank'))
    ParentTaxId <- xvalue(taxon, '/Taxon/ParentTaxId')
    nm <- xname(taxon, '//OtherNames/*')
    obj <- xvalue(taxon, '//OtherNames/*')[nm != "Name"]
    OtherName <- setNames(obj, nm[nm != "Name"]) %||% NA_character_
    classCDE <- xvalue(taxon, '//OtherNames/Name/ClassCDE')
    dispName <- xvalue(taxon, '//OtherNames/Name/DispName')
    Authority <-  dispName[classCDE == "authority"] %||% NA_character_
    TypeMaterial <- dispName[classCDE == "type material"] %||% NA_character_
    Lineage <- Lineage(
      base::lapply(getNodeSet(taxon, "//LineageEx/Taxon"), function (l) {
        l <- xmlDoc(l)
        new("Taxon_minimal",
            TaxId = xvalue(l, '/Taxon/TaxId'),
            ScientificName = xvalue(l, '/Taxon/ScientificName'),
            Rank = xvalue(l, '/Taxon/Rank'))
      }))
    free(taxon)
    new("Taxon_full", taxMin, ParentTaxId = ParentTaxId,
        OtherName = OtherName, Authority = Authority,
        TypeMaterial = TypeMaterial, Lineage = Lineage)
  })
  
  if (length(tx) == 1)
    tx[[1]]
  else
    TaxonList(tx)
}
