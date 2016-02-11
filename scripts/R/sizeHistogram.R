options(bitmapType='cairo')

args <- commandArgs(TRUE)
dir<-args[1]
fileName<-args[2]
laneName<-args[3]
plotName<-args[4]

setwd(dir)

pngfile<-paste(fileName,".png",sep='')
png(pngfile,height=600,width=600)

if((file.info(fileName)[[1]][1]) > 0) {
	data<-read.table(fileName,header=F,sep="\t")
	occurances<-data[,1]
	occurances.trimmed <- occurances[occurances<=800] 
	
	occurances.mean=mean(occurances.trimmed)
	occurances.sd=sd(occurances.trimmed)

	hist(occurances.trimmed,breaks=seq(0,800,5),ylab="Number of junctions",xlab="Molecule Size (bp)",main=paste("Molecule Size Distribution\n",laneName,"-",plotName,"\nmean=",occurances.mean,"\tsd=",occurances.sd,sep=" "),col="grey")
	
	abline(v=occurances.mean,col=rgb(0,0,1,0.4),lwd=3)
	abline(v=occurances.mean-occurances.sd,col=rgb(1,0,0,0.4),lwd=2,lty=2)
	abline(v=occurances.mean+occurances.sd,col=rgb(1,0,0,0.4),lwd=2,lty=2)

} else {
	plot(0,0,ylab="Probability Density",xlab="Molecule Size Distribution",main="ERROR - Found 0 valid reads to generate a histogram",col="grey");
}

dev.off()