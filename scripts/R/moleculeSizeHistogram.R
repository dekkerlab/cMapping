options(bitmapType='cairo')

args <- commandArgs(TRUE)
dir<-args[1]
inputFile<-args[2]

setwd(dir)

pngfile<-paste(inputFile,".png",sep='')
png(pngfile,height=600,width=600)

myData<-read.table(inputFile,header=T,sep="\t")
myData.size<-nrow(myData)
moleculeSizes<-myData$moleculeSize

# calculate the top/bottton 1% of data
moleculeSizes.topIndex<-floor(myData.size*0.999)-1
moleculeSizes.bottomIndex<-ceiling(myData.size*0.001)+1
topLimit<-moleculeSizes[moleculeSizes.topIndex]
bottomLimit<-moleculeSizes[moleculeSizes.bottomIndex]

# remove top 1% of outliers
myData2<-subset(myData,moleculeSize<topLimit)
moleculeSizes<-myData2$moleculeSize

binStep<-1
to<-(topLimit+binStep)
bins<-seq(0,to,by=binStep)
histData<-hist(moleculeSizes,breaks=bins,plot=FALSE)
histMode <- mean(histData$mids[histData$counts == max(histData$counts)])

topLimit<-(histMode*6)

# now subset data
myData2<-subset(myData,myData$moleculeSize<=topLimit)
moleculeSizes<-myData2$moleculeSize

binStep<-1
to<-(topLimit+binStep)
bins<-seq(0,to,by=binStep)
hist(moleculeSizes,breaks=bins,ylab="total reads",xlab="molecule size (bp)",main="dangling end molecule size distribution")

abline(v=histMode,col="red",lwd=3)
legendLabel<-paste("mode moleule size = ",histMode,sep="")
legend("topright", legendLabel,pch=16,col="red",xjust=1,yjust=1)

dev.off()