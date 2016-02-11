options(bitmapType='cairo')

plotField <- function(myData,fieldName,extraTitle,filterValidPairOnlyFlag) {
	
	dataVector<-myData[[fieldName]]
	uFields<-as.vector(unique(dataVector))
	
	# subset only valid pair if mode = directionClassification
	if(filterValidPairOnlyFlag == 1) {
		myData<-subset(myData,myData$interactionType == "validPair")
	}
		
	slices <- numeric(0)
	lbls <- numeric(0)
	for (i in 1:length(uFields) ) {
		field<-uFields[i]				
		tmpCount<-(sum(myData[ which(myData[[fieldName]] == field), ]$count))
		
		if(field != "NA") {
			slices <- c(slices,tmpCount)
			lbls <- c(lbls,field)
		}
		
	}
	
	totalReads<-sum(slices)
	pct <- round(((slices/totalReads)*100),2)
	lbls <- paste(lbls," - ",pct,"%",sep="") # add percents to labels 
	pie(slices,clockwise=TRUE,labels = lbls, col=rainbow(length(lbls)),main=paste(fieldName," (",prettyNum(totalReads,big.mark=",",scientific=F),")","\n",extraTitle))

}

args <- commandArgs(TRUE)
dir<-args[1]
inputFile<-args[2]

setwd(dir)

pngfile<-paste(inputFile,".png",sep='')
png(pngfile,height=800,width=1200)

myData<-read.table(inputFile,header=T,sep="\t",na.strings="")

par(mfrow=c(2,2))
par(cex=1)
par(xpd=TRUE)
par(mar=c(7, 7, 7, 7) + 0.2)
options("scipen"=100, "digits"=4)

plotField(myData,"interactionType","all reads",0)
plotField(myData,"interactionClassification","validPair only",1)
plotField(myData,"directionClassification","validPair only",1)
plotField(myData,"interactionSubType","danglingEnd only",0)

dev.off()