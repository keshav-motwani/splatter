#' @rdname newParams
#' @importFrom methods new
#' @export
newSplatParams <- function(...) {

    params <- new("SplatParams")
    params <- setParams(params, ...)

    return(params)
}

#' @importFrom checkmate checkInt checkIntegerish checkNumber checkNumeric
#' @importFrom checkmate checkLogical
#' checkFlag
setValidity("SplatParams", function(object) {

    object <- expandParams(object)
    v <- getParams(object, c(slotNames(object)))

    nBatches <- v$nBatches
    nGroups <- v$nGroups
    checks <- c(nGenes = checkInt(v$nGenes, lower = 1),
                nCells = checkInt(v$nCells, lower = 1),
                nBatches = checkInt(v$nBatches, lower = 1),
                batchCells = checkIntegerish(v$batchCells, lower = 1,
                                             len = nBatches),
                batch.facLoc = checkNumeric(v$batch.facLoc, len = nBatches),
                batch.facScale = checkNumeric(v$batch.facScale, lower = 0,
                                              len = nBatches),
                batch.rmEffect = checkLogical(v$batch.rmEffect, len = 1),
                mean.rate = checkNumber(v$mean.rate, lower = 0),
                mean.shape = checkNumber(v$mean.shape, lower = 0),
                lib.loc = checkNumber(v$lib.loc),
                lib.scale = checkNumber(v$lib.scale, lower = 0),
                lib.norm = checkFlag(v$lib.norm),
                out.prob = checkNumber(v$out.prob, lower = 0, upper = 1),
                out.facLoc = checkNumber(v$out.facLoc),
                out.facScale = checkNumber(v$out.facScale, lower = 0),
                nGroups = checkInt(v$nGroups, lower = 1),
                splits.per.level = checkNumeric(v$splits.per.level, lower = 1),
                group.prob = checkNumeric(v$group.prob, lower = 0, upper = 1,
                                          len = nGroups),
                de.prob = checkNumeric(v$de.prob, lower = 0, upper = 1,
                                       len = nGroups),
                de.downProb = checkNumeric(v$de.downProb, lower = 0, upper = 1,
                                           len = nGroups),
                de.facLoc = checkNumeric(v$de.facLoc, len = nGroups),
                de.facScale = checkNumeric(v$de.facScale, lower = 0,
                                           len = nGroups),
                de.prob.per.level = checkNumeric(v$de.prob.per.level, lower = 0, upper = 1,
                                       len = length(v$splits.per.level)),
                de.downProb.per.level = checkNumeric(v$de.downProb.per.level, lower = 0, upper = 1,
                                           len = length(v$splits.per.level)),
                de.facLoc.per.level = checkNumeric(v$de.facLoc.per.level, len = length(v$splits.per.level)),
                de.facScale.per.level = checkNumeric(v$de.facScale.per.level, lower = 0,
                                           len = length(v$splits.per.level)),
                bcv.common = checkNumber(v$bcv.common, lower = 0),
                bcv.df = checkNumber(v$bcv.df, lower = 0),
                dropout.type = checkCharacter(v$dropout.type, len = 1,
                                              any.missing = FALSE),
                dropout.mid = checkNumeric(v$dropout.mid, finite = TRUE,
                                           any.missing = FALSE, min.len = 1),
                dropout.shape = checkNumeric(v$dropout.shape, finite = TRUE,
                                             any.missing = FALSE, min.len = 1),
                path.from = checkIntegerish(v$path.from, lower = 0,
                                            upper = nGroups, len = nGroups),
                path.nSteps = checkIntegerish(v$path.nSteps, lower = 1,
                                              len = nGroups),
                path.skew = checkNumeric(v$path.skew, lower = 0, upper = 1,
                                         len = nGroups),
                path.nonlinearProb = checkNumber(v$path.nonlinearProb,
                                                 lower = 0, upper = 1),
                path.sigmaFac = checkNumber(v$path.sigmaFac, lower = 0),
                seed = checkInt(v$seed, lower = 0))

    # Check batchCells matches nCells, nBatches
    if (v$nCells != sum(v$batchCells) || nBatches != length(v$batchCells)) {
        checks <- c(checks,
                    "nCells, nBatches and batchesCells are not consistent")
    }

    # Check group.prob sums to 1
    if (round(sum(v$group.prob), 5) != 1) {
        checks <- c(checks, "group.probs must sum to 1")
    }

    # Check path.from
    if (!(0 %in% v$path.from)) {
        checks <- c(checks, path.from = "origin must be specified in path.from")
    } else if (any(v$path.from == seq_len(nGroups))) {
        checks <- c(checks, "path cannot begin at itself")
    } else if (nGroups > 1 && all(v$path.from <= nGroups)) {
        nodes <- seq_along(v$path.from)
        # Create empty degree and adjacency matrix
        adj <- matrix(0, ncol = length(v$path.from) + 1,
                      nrow = length(v$path.from) + 1)
        deg <- adj
        # Fill adjacency matrix
        adj[(v$path.from + 1) + nrow(adj) * nodes] <- 1
        # Covert to undirected by making symmetrical
        adj <- adj + t(adj)

        # Fill degree matrix and calculate Laplacian
        diag(deg) <- rowSums(adj)
        lap <- deg - adj

        # See https://stackoverflow.com/a/25537032 for explanation of this test
        lap.trace <- sum(diag(lap))
        lap.rank <- qr(lap)$rank

        if (0.5 * lap.trace != lap.rank) {
            checks <- c(checks, "path.from cannot contain cycles")
        }
    }

    # Check dropout type
    if (!(v$dropout.type %in%
          c("none", "experiment", "batch", "group", "cell"))) {
        checks <- c(checks,
                    paste("dropout.type must be one of: 'none', 'experiment',",
                          "'batch', 'group', 'cell'"))
    }

    if (all(checks == TRUE)) {
        valid <- TRUE
    } else {
        valid <- checks[checks != TRUE]
        valid <- paste(names(valid), valid, sep = ": ")
    }

    return(valid)
})

#' @rdname setParam
setMethod("setParam", "SplatParams", function(object, name, value) {
    checkmate::assertString(name)

    if (name == "path.length") {
        warning("path.length has been renamed path.nSteps, ",
                "please use path.nSteps in the future.")
        name <- "path.nSteps"
    }

    if (name == "nCells" || name == "nBatches") {
        stop(name, " cannot be set directly, set batchCells instead")
    }

    if (name == "nGroups") {
        stop(name, " cannot be set directly, set group.prob instead")
    }

    if (name == "batchCells") {
        object <- setParamUnchecked(object, "nCells", sum(value))
        object <- setParamUnchecked(object, "nBatches", length(value))
    }

    # both splits.per.level and group.prob have to agree, and both can change nGroups
    # if both don't agree, then reset the other and give a warning
    # however, if both are set at the same time and agree in given parameters, still get a warning when not needed
    # because parameters are updated one at a time and checked as each is updated

    if (name == "splits.per.level") {
        nGroups = prod(value)
        object <- setParamUnchecked(object, "nGroups", nGroups)
        group.prob <- getParam(object, "group.prob")
        if (length(group.prob) != nGroups) {
            warning("nGroups has changed as a result of changing splits.per.level, resetting group.prob to uniform")
            object <- setParamUnchecked(object, "group.prob", rep(1/nGroups, nGroups))
        }
    }

    if (name == "group.prob") {
        object <- setParamUnchecked(object, "nGroups", length(value))
        path.from <- getParam(object, "path.from")
        if (length(path.from) > 1 & length(path.from) != length(value)) {
            warning("nGroups has changed, resetting path.from")
            object <- setParam(object, "path.from", 0)
        }
        splits.per.level = getParam(object, "splits.per.level")
        if (length(value) != prod(splits.per.level)) {
            if (length(splits.per.level) != 1) warning("nGroups has changed as a result of changing group.prob, resetting splits.per.level to have only 1 level")
            object <- setParamUnchecked(object, "splits.per.level", length(value))
        }
    }

    if (name == "dropout.type") {
        mid.len <- length(getParam(object, "dropout.mid"))
        mid.shape <- length(getParam(object, "dropout.shape"))
        if ((value == "experiment")) {
            if ((mid.len != 1) | (mid.shape != 1)) {
                stop("dropout.type cannot be set to 'experiment' because ",
                     "dropout.mid and dropout.shape aren't length 1, ",
                     "set dropout.mid and dropout.shape first")
            }
        }
        if ((value == "batch")) {
            n <- getParam(object, "nBatches")
            if ((mid.len != n) | (mid.shape != n)) {
                stop("dropout.type cannot be set to 'batch' because ",
                     "dropout.mid and dropout.shape aren't length equal to ",
                     "nBatches (", n, "), set dropout.mid and dropout.shape ",
                     "first")
            }
        }
        if ((value == "group")) {
            n <- getParam(object, "nGroups")
            if ((mid.len != n) | (mid.shape != n)) {
                stop("dropout.type cannot be set to 'group' because ",
                     "dropout.mid and dropout.shape aren't length equal to ",
                     "nGroups (", n, "), set dropout.mid and dropout.shape ",
                     "first")
            }
        }
        if ((value == "cell")) {
            n <- getParam(object, "nCells")
            if ((mid.len != n) | (mid.shape != n)) {
                stop("dropout.type cannot be set to 'cell' because ",
                     "dropout.mid and dropout.shape aren't length equal to ",
                     "nCells (", n, "), set dropout.mid and dropout.shape ",
                     "first")
            }
        }
    }

    object <- callNextMethod()

    return(object)
})

#' @rdname setParams
setMethod("setParams", "SplatParams", function(object, update = NULL, ...) {

    checkmate::assertClass(object, classes = "SplatParams")
    checkmate::assertList(update, null.ok = TRUE)

    update <- c(update, list(...))

    update <- bringItemsForward(update, c("batchCells", "splits.per.level", "group.prob"))

    object <- callNextMethod(object, update)

    return(object)
})

#' @importFrom methods callNextMethod
setMethod("show", "SplatParams", function(object) {

    pp <- list("Batches:"        = c("[Batches]"      = "nBatches",
                                     "[Batch Cells]"  = "batchCells",
                                     "[Location]"     = "batch.facLoc",
                                     "[Scale]"        = "batch.facScale",
                                     "[Remove]"       = "batch.rmEffect"),
               "Mean:"           = c("(Rate)"         = "mean.rate",
                                     "(Shape)"        = "mean.shape"),
               "Library size:"   = c("(Location)"     = "lib.loc",
                                     "(Scale)"        = "lib.scale",
                                     "(Norm)"         = "lib.norm"),
               "Exprs outliers:" = c("(Probability)"  = "out.prob",
                                     "(Location)"     = "out.facLoc",
                                     "(Scale)"        = "out.facScale"),
               "Groups:"         = c("[Groups]"       = "nGroups",
                                     "[Splits per level]"  = "splits.per.level",
                                     "[Group Probs]"  = "group.prob"),
               "Diff expr:"      = c("[Probability]"  = "de.prob",
                                     "[Down Prob]"    = "de.downProb",
                                     "[Location]"     = "de.facLoc",
                                     "[Scale]"        = "de.facScale"),
               "Hierarchical diff expr:"      = c("[Probability per level]"  = "de.prob.per.level",
                                     "[Down Prob per level]"    = "de.downProb.per.level",
                                     "[Location per level]"     = "de.facLoc.per.level",
                                     "[Scale per level]"        = "de.facScale.per.level"),
               "BCV:"            = c("(Common Disp)"  = "bcv.common",
                                     "(DoF)"          = "bcv.df"),
               "Dropout:"        = c("[Type]"         = "dropout.type",
                                     "(Midpoint)"     = "dropout.mid",
                                     "(Shape)"        = "dropout.shape"),
               "Paths:"          = c("[From]"         = "path.from",
                                     "[Steps]"        = "path.nSteps",
                                     "[Skew]"         = "path.skew",
                                     "[Non-linear]"   = "path.nonlinearProb",
                                     "[Sigma Factor]" = "path.sigmaFac"))

    callNextMethod()
    showPP(object, pp)
})

#' @rdname expandParams
setMethod("expandParams", "SplatParams", function(object) {

    n <- getParam(object, "nBatches")

    vectors <- c("batch.facLoc", "batch.facScale")

    object <- paramsExpander(object, vectors, n)

    n <- getParam(object, "nGroups")

    vectors <- c("de.prob", "de.downProb", "de.facLoc", "de.facScale",
                 "path.from", "path.nSteps", "path.skew")

    object <- paramsExpander(object, vectors, n)

    n <- length(getParam(object, "splits.per.level"))

    vectors <- c("de.prob.per.level", "de.downProb.per.level", "de.facLoc.per.level", "de.facScale.per.level")

    object <- paramsExpander(object, vectors, n)

    return(object)
})
