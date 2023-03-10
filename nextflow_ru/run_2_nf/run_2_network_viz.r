
library(dplyr)
library(stringr)
library(tximport)
library(DESeq2)
library("pheatmap")
library(ggplot2)
library(ggvenn)
library(WGCNA)
library(gridExtra)
library(ggdendro)
library(ggrepel)
library(igraph)
library("scales")

# variable to choose which transcriptome to work with
# values can be either "NCBI" or "ensembl"
transcriptome = "ensembl"

# The first network I want to investigate is the lightcyan network
if (transcriptome == "ensembl") {
    load("/home/humebc/projects/ru/nextflow_ru/run_2_nf/light_cyan_module_genes_names.non_shaking.ensembl.RData")
    load("/home/humebc/projects/ru/nextflow_ru/run_2_nf/adjacency.non_shaking.ensembl.RData")
}
if (transcriptome == "NCBI") {
    load("/home/humebc/projects/ru/nextflow_ru/run_2_nf/light_cyan_module_genes_names.non_shaking.RData")
    load("/home/humebc/projects/ru/nextflow_ru/run_2_nf/adjacency.non_shaking.RData")
}

# head(module_gene_names)
# head(adjacency)

# subset the adjacency matrix to only the light cyan module genes.
adjacency_sub = adjacency[module_gene_names, module_gene_names]
data.frame(connectivity=rowSums(adjacency_sub)) %>% arrange(desc(connectivity))

# Strip out the < 0.5 connections and drop any genes that only had < 0.5 connections
h_thresh = 0.5
adjacency_sub[adjacency_sub < h_thresh] <- 0
keep = rowSums(adjacency_sub) > 1
adjacency_sub = adjacency_sub[keep, keep]

# Count the connections
# PHATRDRAFT_38705
connections = data.frame(connections=rowSums(adjacency_sub>0)) %>% arrange(desc(connections))
# strip out nodes that only connect to 2 other node
keep = rownames(connections %>% dplyr::filter(connections>3))
adjacency_sub = adjacency_sub[keep, keep]

# repeat
connections = data.frame(connections=rowSums(adjacency_sub>0)) %>% arrange(desc(connections))
# strip out nodes that only connect to 2 other node
keep = rownames(connections %>% dplyr::filter(connections>3))
adjacency_sub = adjacency_sub[keep, keep]

# This is the threshold for showing a connection
net <- graph_from_adjacency_matrix(adjacency_sub, mode="undirected", weighted=TRUE, diag=FALSE)
E(net)$width <- E(net)$weight *0.5
V(net)$size <- 7
V(net)$color = ifelse(names(V(net)) == "PHATRDRAFT_43365", "red", "white")
if (transcriptome == "ensembl") {
    png("/home/humebc/projects/ru/nextflow_ru/run_2_nf/lightcyan.non_shaking.network.ensembl.png", height=10, width=10, res=600, units="cm")
}
if (transcriptome == "NCBI") {
    png("/home/humebc/projects/ru/nextflow_ru/run_2_nf/lightcyan.non_shaking.network.png", height=10, width=10, res=600, units="cm")
}

# See section 5.1 for plotting option
# https://kateto.net/networks-r-igraph
plot(net, vertex.label=NA, main="lightcyan module module-trait mutant=0.99")
dev.off()

# This is the list of the genes in this network:
adjacency_sub_names = rownames(adjacency_sub)

if (transcriptome == "ensembl") {
    save(adjacency_sub_names, file="/home/humebc/projects/ru/nextflow_ru/run_2_nf/lightcycan.network.gene.names.ensembl.RData")
}
if (transcriptome == "NCBI") {
    save(adjacency_sub_names, file="/home/humebc/projects/ru/nextflow_ru/run_2_nf/lightcycan.network.gene.names.RData")
}


# Now view the network of the top 10 connectivity genes
top_10_names = rownames(head(connections, 10))
top_10_adj = adjacency_sub[top_10_names, top_10_names]
net_top_10 <- graph_from_adjacency_matrix(top_10_adj, mode="undirected", weighted=TRUE, diag=FALSE)
E(net_top_10)$width <- E(net_top_10)$weight *0.5
V(net_top_10)$size <- 7
V(net_top_10)$color = ifelse(names(V(net_top_10)) == "PHATRDRAFT_43365", "red", "white")

if (transcriptome == "ensembl") {
    png("/home/humebc/projects/ru/nextflow_ru/run_2_nf/lightcyan.non_shaking.network.top10.ensembl.png", height=10, width=10, res=600, units="cm")
}
if (transcriptome == "NCBI") {
    png("/home/humebc/projects/ru/nextflow_ru/run_2_nf/lightcyan.non_shaking.network.top10.png", height=10, width=10, res=600, units="cm")
}

# See section 5.1 for plotting option
# https://kateto.net/networks-r-igraph
plot(net_top_10, vertex.label=NA)
dev.off()



##################

# gpplot version of the full network.

##################
# It would be good to have this as a dataframe so that we can plot it up using ggplot
# it would also be good to have some idea of the GS.axenic significance score
# we could use the node size to represent that.

# Produce dataframes of the vertice and edge information 
edge_df = as_data_frame(net, what="edges")
head(edge_df)
vert_df = as_data_frame(net, what="vertices")
head(vert_df)

# Load the Gene Significance df
if (transcriptome == "ensembl") {
    load("/home/humebc/projects/ru/nextflow_ru/run_2_nf/geneTraitSignificance.non_shaking.ensembl.RData")
}
if (transcriptome == "NCBI") {
    load("/home/humebc/projects/ru/nextflow_ru/run_2_nf/geneTraitSignificance.non_shaking.RData")
}

head(geneTraitSignificance)
V(net)$x
plot(net, layout=layout.auto)
coords = layout_nicely(graph=net)
net_df_coords = data.frame(x=coords[,1], y=coords[,2], name=vert_df$name, size=vert_df$size, color=vert_df$color)
rownames(net_df_coords) = net_df_coords$name
net_df_coords$GS = geneTraitSignificance[rownames(net_df_coords),"GS.axenic"]

# To do the edges we need to create a df that has the following for every edge:
# from.x, from.y, to.x, to.y, weight, width
# we will pull this information out as vectors and then combine in a dataframe for plotting
from.x = net_df_coords$x[sapply(edge_df$from, match, net_df_coords$name)]
from.y = net_df_coords$y[sapply(edge_df$from, match, net_df_coords$name)]
to.x = net_df_coords$x[sapply(edge_df$to, match, net_df_coords$name)]
to.y = net_df_coords$y[sapply(edge_df$to, match, net_df_coords$name)]
net_edge_df = data.frame(from=edge_df$from, to=edge_df$to, from.x=from.x, from.y=from.y, to.x=to.x, to.y=to.y, weight=edge_df$weight, width=edge_df$width)

# It is not possible to have a separate legend for each of the size attributes (i.e. the one used for the points and the one used for the lines)
# https://stackoverflow.com/questions/14647794/using-multiple-size-scales-in-a-ggplot



if (transcriptome == "ensembl") {
    ggplot() + 
    geom_segment(data=net_edge_df, aes(x=from.x,xend = to.x, y=from.y,yend = to.y, size=weight), colour="grey") + 
    geom_point(data=net_df_coords, color="black", fill=net_df_coords$color, shape=21, size=rescale(net_df_coords$GS, c(10,20)), aes(x=x, y=y)) + 
    geom_text(data=net_df_coords, aes(label=name, x=x, y=y)) +
    theme_bw() + 
    theme(panel.grid.major = element_blank(),
        panel.grid.minor = element_blank(),
        panel.border = element_blank(),
        panel.background = element_blank(),
        axis.ticks = element_blank(),
            axis.text = element_blank()) + xlab("") + ylab("") +
    guides(size = guide_legend("adjacency score (weight)")) + xlim(c(-6, 4)) +
    ggtitle("Network of lightcyan module according to their adjacency scores (connections >0.5 shown; > 3 connections only)")
    ggsave("/home/humebc/projects/ru/nextflow_ru/run_2_nf/lightcyan.non_shaking.network.ggplot.ensembl.png", height=50, width=40, units="cm")
}
if (transcriptome == "NCBI") {
    ggplot() + 
geom_segment(data=net_edge_df, aes(x=from.x,xend = to.x, y=from.y,yend = to.y, size=weight), colour="grey") + 
geom_point(data=net_df_coords, color="black", fill=net_df_coords$color, shape=21, size=rescale(net_df_coords$GS, c(10,20)), aes(x=x, y=y)) + 
geom_text(data=net_df_coords, aes(label=name, x=x, y=y)) +
theme_bw() + 
theme(panel.grid.major = element_blank(),
    panel.grid.minor = element_blank(),
    panel.border = element_blank(),
    panel.background = element_blank(),
    axis.ticks = element_blank(),
        axis.text = element_blank()) + xlab("") + ylab("") +
guides(size = guide_legend("adjacency score (weight)")) + xlim(c(-4.5, 4.5)) +
ggtitle("Network of lightcyan module according to their adjacency scores (connections >0.5 shown; > 3 connections only)")
    ggsave("/home/humebc/projects/ru/nextflow_ru/run_2_nf/lightcyan.non_shaking.network.ggplot.png", height=50, width=40, units="cm")
}


##################

# gpplot version of the top10 network.

##################
# It would be good to have this as a dataframe so that we can plot it up using ggplot
# it would also be good to have some idea of the GS.axenic significance score
# we could use the node size to represent that.

# Produce dataframes of the vertice and edge information 
edge_df_top_10 = as_data_frame(net_top_10, what="edges")
head(edge_df_top_10)
vert_df_top_10 = as_data_frame(net_top_10, what="vertices")
head(vert_df_top_10)

coords_top_10 = layout_nicely(graph=net_top_10)
net_df_coords_to_10 = data.frame(x=coords_top_10[,1], y=coords_top_10[,2], name=vert_df_top_10$name, size=vert_df_top_10$size, color=vert_df_top_10$color)
rownames(net_df_coords_to_10) = net_df_coords_to_10$name
net_df_coords_to_10$GS = geneTraitSignificance[rownames(net_df_coords_to_10),"GS.axenic"]

# To do the edges we need to create a df that has the following for every edge:
# from.x, from.y, to.x, to.y, weight, width
# we will pull this information out as vectors and then combine in a dataframe for plotting
from.x.t.10 = net_df_coords_to_10$x[sapply(edge_df_top_10$from, match, net_df_coords_to_10$name)]
from.y.t.10 = net_df_coords_to_10$y[sapply(edge_df_top_10$from, match, net_df_coords_to_10$name)]
to.x.t.10 = net_df_coords_to_10$x[sapply(edge_df_top_10$to, match, net_df_coords_to_10$name)]
to.y.t.10 = net_df_coords_to_10$y[sapply(edge_df_top_10$to, match, net_df_coords_to_10$name)]
net_edge_df_top_10 = data.frame(from=edge_df_top_10$from, to=edge_df_top_10$to, from.x=from.x.t.10, from.y=from.y.t.10, to.x=to.x.t.10, to.y=to.y.t.10, weight=edge_df_top_10$weight, width=edge_df_top_10$width)

# It is not possible to have a separate legend for each of the size attributes (i.e. the one used for the points and the one used for the lines)
# https://stackoverflow.com/questions/14647794/using-multiple-size-scales-in-a-ggplot
if (transcriptome == "ensembl") {
    ggplot() + 
    geom_segment(data=net_edge_df_top_10, aes(x=from.x,xend = to.x, y=from.y,yend = to.y, size=weight), colour="grey") + 
    geom_point(data=net_df_coords_to_10, color="black", fill=net_df_coords_to_10$color, shape=21, size=rescale(net_df_coords_to_10$GS, c(10,20)), aes(x=x, y=y)) + 
    geom_text(data=net_df_coords_to_10, aes(label=name, x=x, y=y)) + 
    theme_bw() + 
    theme(panel.grid.major = element_blank(),
        panel.grid.minor = element_blank(),
        panel.border = element_blank(),
        panel.background = element_blank(),
        axis.ticks = element_blank(),
            axis.text = element_blank()) + xlab("") + ylab("") +
    guides(size = guide_legend("adjacency score (weight)")) + xlim(c(0.2, 1.7)) +
    ggtitle("Network of lightcyan module according to their adjacency scores (connections >0.5 shown; > 3 connections only)")
    ggsave("/home/humebc/projects/ru/nextflow_ru/run_2_nf/lightcyan.non_shaking.network.top_10.ggplot.ensembl.png", height=50, width=40, units="cm")
}
if (transcriptome == "NCBI") {
    ggplot() + 
    geom_segment(data=net_edge_df_top_10, aes(x=from.x,xend = to.x, y=from.y,yend = to.y, size=weight), colour="grey") + 
    geom_point(data=net_df_coords_to_10, color="black", fill=net_df_coords_to_10$color, shape=21, size=rescale(net_df_coords_to_10$GS, c(10,20)), aes(x=x, y=y)) + 
    geom_text(data=net_df_coords_to_10, aes(label=name, x=x, y=y)) + 
    theme_bw() + 
    theme(panel.grid.major = element_blank(),
        panel.grid.minor = element_blank(),
        panel.border = element_blank(),
        panel.background = element_blank(),
        axis.ticks = element_blank(),
            axis.text = element_blank()) + xlab("") + ylab("") +
    guides(size = guide_legend("adjacency score (weight)")) + xlim(c(-4.5, -1.25)) +
    ggtitle("Network of lightcyan module according to their adjacency scores (connections >0.5 shown; > 3 connections only)")
    ggsave("/home/humebc/projects/ru/nextflow_ru/run_2_nf/lightcyan.non_shaking.network.top_10.ggplot.png", height=50, width=40, units="cm")
}


##########################

# Networks of the mutant DE genes

#########################

# NB I have stopped here for the ensembl version of the analysis as the network vizualizations are not particularly helpful

# See the run_2_wgcna.r script for how we identified a set of genes that likely represent networks
# We have save the cluster identities
load("/home/humebc/projects/ru/nextflow_ru/run_2_nf/mutant.de.non_shaking.adjacency.dendro.clusters.RData")
head(gene_clusters)
# and we saved the adjacency matrix to work with that contains the genes that were DE mutant
load("/home/humebc/projects/ru/nextflow_ru/run_2_nf/adjacency_de.non_shaking.RData")
head(adjacency_de)
# Load the Gene Significance df
load("/home/humebc/projects/ru/nextflow_ru/run_2_nf/geneTraitSignificance.non_shaking.RData")
head(geneTraitSignificance)

# We want to make networks from 4 collections of genes
# cluster 1
# cluster 3
# clusters 9, 12 and 7 (one network)
# cluster 11 
# We will aim to make a function that takes the set of clusters to work with
# and in the function produce the ggplot version of the network as we have done above.

cluster_vector = c(3)
make_network = function(cluster_vector){

    gene_names = names(gene_clusters[gene_clusters %in% cluster_vector])
    # subset the adjacency matrix to only the DE genes of the modules
    adjacency_sub = adjacency_de[gene_names, gene_names]
    data.frame(connectivity=rowSums(adjacency_sub)) %>% arrange(desc(connectivity))

    # Strip out the < 0.5 connections and drop any genes that only had < 0.5 connections
    h_thresh = 0.5
    adjacency_sub[adjacency_sub < h_thresh] <- 0
    keep = rowSums(adjacency_sub) > 1
    adjacency_sub = adjacency_sub[keep, keep]

    # Count the connections
    # PHATRDRAFT_38705
    connections = data.frame(connections=rowSums(adjacency_sub>0)) %>% arrange(desc(connections))
    # strip out nodes that only connect to 2 other node
    keep = rownames(connections %>% dplyr::filter(connections>3))
    adjacency_sub = adjacency_sub[keep, keep]

    # repeat
    connections = data.frame(connections=rowSums(adjacency_sub>0)) %>% arrange(desc(connections))
    # strip out nodes that only connect to 2 other node
    keep = rownames(connections %>% dplyr::filter(connections>3))
    adjacency_sub = adjacency_sub[keep, keep]

    # This is the threshold for showing a connection
    net <- graph_from_adjacency_matrix(adjacency_sub, mode="undirected", weighted=TRUE, diag=FALSE)
    E(net)$width <- E(net)$weight *0.5
    V(net)$size <- 7
    V(net)$color = ifelse(names(V(net)) == "PHATRDRAFT_43365", "red", "white")
    cluster_str = str_c(cluster_vector, collapse="_")
    # png(paste0("/home/humebc/projects/ru/nextflow_ru/run_2_nf/mutant.de.networks.clusters.", cluster_str, ".non_shaking.network.png"), height=10, width=10, res=600, units="cm")
    # # See section 5.1 for plotting option
    # # https://kateto.net/networks-r-igraph
    # plot(net, vertex.label=NA, main="lightcyan module module-trait mutant=0.99")
    # dev.off()

    ##################

    # gpplot version

    ##################

    # Produce dataframes of the vertice and edge information 
    edge_df = as_data_frame(net, what="edges")
    head(edge_df)
    vert_df = as_data_frame(net, what="vertices")
    head(vert_df)

    coords = layout_nicely(graph=net)
    net_df_coords = data.frame(x=coords[,1], y=coords[,2], name=vert_df$name, size=vert_df$size, color=vert_df$color)
    rownames(net_df_coords) = net_df_coords$name
    net_df_coords$GS = geneTraitSignificance[rownames(net_df_coords),"GS.axenic"]

    # To do the edges we need to create a df that has the following for every edge:
    # from.x, from.y, to.x, to.y, weight, width
    # we will pull this information out as vectors and then combine in a dataframe for plotting
    from.x = net_df_coords$x[sapply(edge_df$from, match, net_df_coords$name)]
    from.y = net_df_coords$y[sapply(edge_df$from, match, net_df_coords$name)]
    to.x = net_df_coords$x[sapply(edge_df$to, match, net_df_coords$name)]
    to.y = net_df_coords$y[sapply(edge_df$to, match, net_df_coords$name)]
    net_edge_df = data.frame(from=edge_df$from, to=edge_df$to, from.x=from.x, from.y=from.y, to.x=to.x, to.y=to.y, weight=edge_df$weight, width=edge_df$width)

    # It is not possible to have a separate legend for each of the size attributes (i.e. the one used for the points and the one used for the lines)
    # https://stackoverflow.com/questions/14647794/using-multiple-size-scales-in-a-ggplot
    ggplot() + 
    geom_segment(data=net_edge_df, aes(x=from.x,xend = to.x, y=from.y,yend = to.y, linewidth=weight), colour="grey") + 
    geom_point(data=net_df_coords, color="black", fill=net_df_coords$color, shape=21, size=rescale(net_df_coords$GS, c(10,20)), aes(x=x, y=y)) + 
    geom_text(data=net_df_coords, aes(label=name, x=x, y=y)) + 
    theme_bw() + 
    theme(panel.grid.major = element_blank(),
        panel.grid.minor = element_blank(),
        panel.border = element_blank(),
        panel.background = element_blank(),
        axis.ticks = element_blank(),
            axis.text = element_blank()) + xlab("") + ylab("") +
    guides(size = guide_legend("adjacency score (weight)")) + 
    ggtitle(paste0("Network of mnutant DE genes to their adjacency scores (connections >0.5 shown; > 3 connections only) cluster:", cluster_str))

    ggsave(paste0("/home/humebc/projects/ru/nextflow_ru/run_2_nf/mutant.de.networks.clusters.", cluster_str, ".non_shaking.network.ggplot.png"), height=50, width=40, units="cm")
}
make_network(c(1))
make_network(c(3))
make_network(c(11))
make_network(c(9,12,7))