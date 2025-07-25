# ================================================================= #
# == R code to replicate the center and right panels of Figure 5 == #
# == Author: Ethan Ancell                                        == #
# ================================================================= #

library("networkinference")
library("tidyverse")
library("nett")
library("mclust")
library("latex2exp")
library("networkinference")

ggplot2::theme_set(theme_minimal())

# =========================
# == Simulation settings ==
# =========================

set.seed(1)
num_sim <- 5000 # Number of replications

n_check <- c(200) # Total network size
K_check <- c(5) # Guessed number of communities
K_true_check <- c(5)
eps_check <- c(0.10, 0.20, 0.30, 0.40, 0.50, 0.60, 0.70, 0.80, 0.90)
signal_regimes <- list(c(30, 29), c(30, 27), c(30, 25), c(30, 23), c(30, 21)) # Signal regimes for mean matrix

# ====================== #
# == Simulation setup == #
# ====================== #

# Unpack rho_1 and rho_2 from the signal regimes
rho_1 <- signal_regimes[[1]][1] # Assumes that this stays the same across all of them
rho_2_check <- rep(NA, length(signal_regimes))
for (i in 1:length(signal_regimes)) {
  rho_2_check[i] <- signal_regimes[[i]][2]
}
rho_1_minus_rho_2 <- rho_1 - rho_2_check

estimates_thinning <- array(0, dim = c(length(n_check),
                                       length(K_true_check),
                                       length(K_check),
                                       length(signal_regimes),
                                       length(eps_check),
                                       num_sim))
targets_thinning <- array(0, dim = c(length(n_check),
                                     length(K_true_check),
                                     length(K_check),
                                     length(signal_regimes),
                                     length(eps_check),
                                     num_sim))
variances_thinning <- array(0, dim = c(length(n_check),
                                       length(K_true_check),
                                       length(K_check),
                                       length(signal_regimes),
                                       length(eps_check),
                                       num_sim))
rand_results <- array(0, dim = c(length(n_check),
                                 length(K_true_check),
                                 length(K_check),
                                 length(signal_regimes),
                                 length(eps_check),
                                 num_sim))

# ==============
# == Simulate ==
# ==============

cat("Simulating for Figure 5 - center and right panels\n")

# Sample size
for (n_index in 1:length(n_check)) {
  n <- n_check[n_index]
  cat(paste0('(n = ', n, ')\n'))

  # True communities
  for (K_true_index in 1:length(K_true_check)) {
    # n_per_community <- n_per_community_check[n_per_community_index]
    K_true <- K_true_check[K_true_index]
    n_per_community <- n / K_true
    cat(paste0('\t(K_true = ', K_true, ')\n'))

    # Number of communities used in clustering
    for (K_index in 1:length(K_check)) {
      K <- K_check[K_index]
      cat(paste0('\t\t(K = ', K, ')\n'))

      # Signal regimes in mean matrix
      for (signal_regime_index in 1:length(signal_regimes)) {
        rho1 <- signal_regimes[[signal_regime_index]][1]
        rho2 <- signal_regimes[[signal_regime_index]][2]
        cat(paste0('\t\t\t(rho1 = ', rho1, ', rho2 = ', rho2, ')\n'))

        # Different values of epsilon in thinning
        for (eps_index in 1:length(eps_check)) {
          eps <- eps_check[eps_index]
          cat(paste0('\t\t\t\t(eps = ', eps, ')\n'))

          # -------------------------------------------------
          # -- Actual simulation part (non just for-loops) --
          # -------------------------------------------------

          # Create mean matrices
          Theta_true <- matrix(rep(rho2, K_true^2), nrow = K_true)
          diag(Theta_true) <- rho1
          M <- matrix(rep(NA, n^2), nrow = n)
          for (k in 1:K_true) {
            for (l in 1:K_true) {
              M[((k-1)*n_per_community + 1):(k*n_per_community),
                ((l-1)*n_per_community + 1):(l*n_per_community)] <- Theta_true[k, l]
            }
          }
          # "True" community membership
          z_true <- rep(1:K_true, each = n_per_community)

          for (rep in 1:num_sim) {

            # Linear combination vector
            u <- c(1, rep(0, K^2 - 1))

            # Draw A
            A <- matrix(rpois(n = n^2, lambda = as.vector(M)), nrow = n)

            # Split A
            A_split <- networkinference::split_network(A, distribution = "poisson",
                                                       epsilon = eps)
            Atr <- A_split$Atr
            Ate <- A_split$Ate

            # Clustering
            z_hat <- nett::spec_clust(Atr, K = K)

            # Check RAND index agreement between true clusters and non true clusters
            rand_results[n_index, K_true_index, K_index, signal_regime_index, eps_index, rep] <- mclust::adjustedRandIndex(z_hat, z_true)

            # Estimator, estimator variance, and target for the proposed approach
            thinning_infer <-
              networkinference::infer_network(Ate = Ate, u = u,
                                              communities = z_hat,
                                              distribution = "poisson",
                                              epsilon = eps)
            estimate <- thinning_infer$estimate
            estimate_var <- thinning_infer$estimate_variance
            target <- networkinference::check_target_of_inference(M = M, u = u,
                                                                  communities = z_hat)

            # Save results
            # ------------
            estimates_thinning[n_index, K_true_index, K_index, signal_regime_index, eps_index, rep] <-
              estimate
            targets_thinning[n_index, K_true_index, K_index, signal_regime_index, eps_index, rep] <-
              target
            variances_thinning[n_index, K_true_index, K_index, signal_regime_index, eps_index, rep] <-
              estimate_var
          }
        }
      }
    }
  }
}

# ================================================ #
# == Save/load results (saves computation time) == #
# ================================================ #

# saveRDS(estimates_thinning, file = "saved_simulation_data/figure_5_center_right_estimates_thinning.RDS")
# saveRDS(targets_thinning, file = "saved_simulation_data/figure_5_center_right_targets_thinning.RDS")
# saveRDS(variances_thinning, file = "saved_simulation_data/figure_5_center_right_variances_thinning.RDS")
# saveRDS(rand_results, file = "saved_simulation_data/figure_5_center_right_rand_results.RDS")

estimates_thinning <- readRDS("saved_simulation_data/figure_5_center_right_estimates_thinning.RDS")
targets_thinning <- readRDS("saved_simulation_data/figure_5_center_right_targets_thinning.RDS")
variances_thinning <- readRDS("saved_simulation_data/figure_5_center_right_variances_thinning.RDS")
rand_results <- readRDS("saved_simulation_data/figure_5_center_right_rand_results.RDS")

# ======================= #
# == Plot center panel == #
# ======================= #

rand_slice <- apply(rand_results[n_index, K_true_index, K_index, , , ], c(1, 2), mean)
eps_index_plotting <- matrix(rep(eps_check, length(signal_regimes)), ncol = length(eps_check), byrow = TRUE)
rho_2_plotting <- matrix(rep(rho_2_check, length(eps_check)), ncol = length(eps_check))
rho_1_minus_rho_2_plotting <- matrix(rep(rho_1_minus_rho_2, length(eps_check)), ncol = length(eps_check))
signal_index_plotting <- matrix(rep(1:length(signal_regimes), length(eps_check)), ncol = length(eps_check))

legend_colors <- c('1' = 'gold3', '3' = 'darkseagreen4',
                   '5' = 'darkslategray4', '7' = 'deeppink4',
                   '9' = 'firebrick3')

plot_df <- data.frame(signal_index = as.vector(signal_index_plotting),
                      rho_2 = as.character(as.vector(rho_2_plotting)),
                      rho_1_minus_rho_2 = as.character(as.vector(rho_1_minus_rho_2_plotting)),
                      rand_index = as.vector(rand_slice),
                      eps = as.vector(eps_index_plotting))
center_figure <- ggplot(plot_df) +
  geom_line(aes(x = eps, y = rand_index, color = rho_1_minus_rho_2), size = 0.9) +
  scale_color_manual(breaks = c('100', '101', '102', '103', '104'), values = legend_colors) +
  xlab(TeX('$\\epsilon')) + ylab('Adjusted RAND Index') +
  coord_fixed() +
  labs(color = TeX('$\\rho_1 - \\rho_2$')) +
  theme(aspect.ratio = 1,
        axis.text.x = element_text(size = 16),
        axis.text.y = element_text(size = 16),
        axis.title.x = element_text(size = 25),
        axis.title.y = element_text(size = 16),
        legend.title = element_text(size = 18),
        legend.text = element_text(size = 15))
center_figure
ggsave('figures/randindex_epsilon_poisson.pdf',
       plot = center_figure, device = 'pdf', width = 4.5, height = 3.5)

# ====================== #
# == Plot right panel == #
# ====================== #

alpha <- 0.10
ci_width <- 2 * qnorm(1 - alpha / 2) * sqrt(variances_thinning[n_index, K_true_index, K_index, , , ])
ci_width <- apply(ci_width, c(1, 2), mean)
eps_index_plotting <- matrix(rep(eps_check, length(signal_regimes)), ncol = length(eps_check), byrow = TRUE)
rho_2_plotting <- matrix(rep(rho_2_check, length(eps_check)), ncol = length(eps_check))
rho_1_minus_rho_2_plotting <- matrix(rep(rho_1_minus_rho_2, length(eps_check)), ncol = length(eps_check))
signal_index_plotting <- matrix(rep(1:length(signal_regimes), length(eps_check)), ncol = length(eps_check))

plot_df <- data.frame(signal_index = as.vector(signal_index_plotting),
                      rho_2 = as.vector(rho_2_plotting),
                      rho_1_minus_rho_2 = as.character(as.vector(rho_1_minus_rho_2_plotting)),
                      ci_width = as.vector(ci_width),
                      eps = as.vector(eps_index_plotting))

legend_colors <- c('1' = 'gold3', '3' = 'darkseagreen4',
                   '5' = 'darkslategray4', '7' = 'deeppink4',
                   '9' = 'firebrick3')
right_figure <- ggplot()
for (ri in 1:length(rho_2_check)) {
  df_subset <- plot_df[plot_df$rho_2 == rho_2_check[ri], ]
  right_figure <- right_figure +
    geom_line(aes(x = eps, y = ci_width, color = rho_1_minus_rho_2), size = 1.0, alpha = 0.7, data = df_subset)
}
right_figure <- right_figure +
  xlab(TeX('$\\epsilon$')) + ylab('Average 90% CI width') +
  scale_color_manual(breaks = c('1', '3', '5', '7', '9'), values = legend_colors) +
  labs(color = TeX('$\\rho_1 - \\rho_2$')) +
  theme(aspect.ratio = 1,
        axis.text.x = element_text(size = 16),
        axis.text.y = element_text(size = 16),
        axis.title.x = element_text(size = 25),
        axis.title.y = element_text(size = 16),
        legend.title = element_text(size = 18),
        legend.text = element_text(size = 15))
right_figure
ggsave('figures/conf_width_epsilon_poisson.pdf',
       plot = right_figure, device = 'pdf', width = 4.5, height = 3.5)
