options(bitmapType='cairo')

args <- commandArgs(TRUE)
file<-args[1]

scatter<-read.table(file,header=F,sep="\t")
x<-scatter[,1]
y<-scatter[,2]
y2<-y
y2<-sort(y2)
ysize<-length(y2)
ysize<-floor(ysize*.998)
ysize<-y2[ysize]


pngfile<-paste(file,"_scatter.png",sep='')

png(pngfile,height=800,width=1200)
plot(x,y,ylim=c(0,ysize),col=rgb(0.25,0.25,0.25,0.5),main="Hi-C Scatter Plot",xlab="Genomic Distance (bp)",ylab="# Reads",cex=0.5)

dev.off()