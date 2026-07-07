context("Joint RPCA")

# Dataset setup -----------------------------------------------------------

data("ibdmdb", package = "mia")

mae <- ibdmdb

mae[[1L]] <- transformAssay(
  mae[[1L]],
  assay.type = "mgx",
  method = "rclr",
  impute = FALSE
)

mae[[2L]] <- transformAssay(
  mae[[2L]],
  assay.type = "mtx",
  method = "rclr",
  impute = FALSE
)

shared_samples <- intersect(
  colnames(mae[[1L]]),
  colnames(mae[[2L]])
)

test_samples <- tail(shared_samples, 2L)


# Successful execution ---------------------------------------------------

test_that("getJointRPCA works on MultiAssayExperiment", {
  result <- getJointRPCA(
    mae,
    experiments = c(1L, 2L),
    assay.types = c("rclr", "rclr"),
    ncomponents = 1L,
    max.iterations = 1L,
    test.set = test_samples
  )
  
  expect_true(is.matrix(result))
  expect_type(result, "double")
  
  expect_identical(ncol(result), 1L)
  expect_identical(colnames(result), "PC1")
  
  expect_identical(nrow(result), length(shared_samples))
  expect_setequal(rownames(result), shared_samples)
  
  expect_true(any(is.finite(result)))
  expect_false(all(is.na(result)))
  
  expected_attributes <- c(
    "varExplained",
    "rotation",
    "percentVar",
    "lower_dim",
    "X",
    "S",
    "Y",
    "cv_error",
    "distance",
    "reconstruct_error"
  )
  
  expect_true(
    all(expected_attributes %in% names(attributes(result)))
  )
  
  expect_length(
    attr(result, "reconstruct_error"),
    2L
  )
})


# Input validation --------------------------------------------------------

test_that("getJointRPCA validates experiment and assay selections", {
  expect_error(
    getJointRPCA(
      mae,
      experiments = c(1L, 2L),
      assay.types = "rclr"
    )
  )
  
  expect_error(
    getJointRPCA(
      mae,
      experiments = 1L,
      assay.types = "rclr"
    )
  )
})


test_that("getJointRPCA validates test.set", {
  expect_error(
    getJointRPCA(
      mae,
      experiments = c(1L, 2L),
      assay.types = c("rclr", "rclr"),
      ncomponents = 1L,
      max.iterations = 1L,
      test.set = 5L
    )
  )
})