/*
https://github.com/BenTommyE/Ben-FFT/presentation.pde 
https://www.local-guru.net/blog/2019/1/22/processing-sound-visualizer-explained 
https://www.local-guru.net/ebook/processing-ebook-beta2.pdf
http://citeseerx.ist.psu.edu/vierenderoc/summary?doi=10.1.1.11.9150  
*/ 
import ddf.minim.analysis.FFT;

class renderAudio{
  // FFT parameters
  int N;
  float S;
  int B;
  int D;
  int M;
  float T;
  FFT fftLib;         // built-in FFT library for error checking
  // sub-window widths ~= W/2, H/2
  int W1;
  int H1;
  float box;

  // audio rendering data
  float[] levL;
  float[] levR;
  float[] LRData;
  // freq rendering data
  float[] xR;
  float[] xI;
  float[] xS;
  float Ts;      // visual scale = (buffer size)/N*(some scale factor)
  float vizSc;   // scale FFT graphs for display
  float levSc;   // default scale for levels top left window bar
  float crvTs;   //0.5; // curve tightness for displaying phase-space graphs
  float crvTsFFT;       // curve tightness for displaying FFT graphs
  float frScale; // = scale/(5.0*T);
  float wScale;
  int tau;
  //int theta;     // D+1 = starting divisor to rotate FFT phase graph => ON HOLD
  int Nmin;
  int ND2;       // FFT band count = N/2
  int NFR;       // # of frequency bands to render <= N/2
  int NBR;       // # of buffer samples to render <= N
  int NBRmax; 
  int NFRmax; 
  float NFRscale;
  // graphing color palette
  color RRed; 
  color LYellow;
  color PRed; 
  color PYellow;
  color EYellow;
  color SWhite;
  color FWhite;
  color PWhite;
  color RGreen;
  color RGreen2;
  color IBlue;
  color FPurple;
  
  // Constructor: initialize window sizes based on sketch size
  renderAudio (int _W, int _H, int _N) {
    N = _N;
    B = N;
    W1 = _W/2;
    H1 = _H/2;
    // limit buffer of audio/freq bands to render
    Nmin = 16;   // lowest allowable value of N that doesn't slow down rendering
    ND2 = N/2;
    NBR = N;
    NFRscale = 1.0; // 0.8; // crop off top 20% by default
    NFR = int(ND2*NFRscale);
    // running display of R/L channel levels
    levL = new float[W1+1];
    levR = new float[W1+1];
    LRData = new float[N];
    // default scaling for PPS & FFT winding
    vizSc = 0.5;  
    levSc = 0.25; 
    crvTs = 0.0; 
    crvTsFFT = 0.1;
    frScale = 1.0; 
    wScale = frScale;
    tau = 10;
    RRed = color(220,0,0,255);
    PRed = color(220,0,0,180);
    LYellow = color(220,220,0,255);
    PYellow = color(220,220,0,180);
    EYellow = color(230,230,0); //(230,230,0,180); 
    SWhite = color(255);
    FWhite = color(255, 200); 
    PWhite = color(255, 120); // 255,150
    RGreen = color(0,255,0); 
    RGreen2 = color(0,200,0);
    IBlue = color(0,200,255); 
    FPurple = color(200,0,200,180); 
  }
  
  // print changes in N to screen
  void setNSB(int _N, float _S, int _B) 
  {
    println("set N ",_N); 
    N = _N;
    S = _S;
    B = _B;
    D = int(log(B)/log(2));
    M = int(log(N)/log(2));
    T = float(B)/S;
    ND2 = N/2; 
    NFR = min(int(ND2*NFRscale),ND2); // 250
    NBR = min(B,N);   // 800
    Ts = B/float(ND2)*vizSc;
    levSc = 0.25;   // default scale for levels
    xR = null;
    xI = null;
    xS = null;
    xS = new float[N];
    if (fftLib != null ) {
      fftLib = null;
    }
    fftLib = new FFT( N, S );
  }
  // set upper limit on frequency axis
  void setNFR(boolean _UP) { 
    if (_UP) {
      NFRscale = min(1.0, NFRscale+1/32.0);
    } else {
      NFRscale = max(0.3, NFRscale-1/32.0);
    }
    NFR = min(int(ND2*NFRscale),ND2);
    println("set F ", NFR);
  }
  
  void drawGrid(int _count, int _grid, color c) {
    noFill();
    stroke(c);
    box = _count*_grid/2.0;
    for (int i = 0; i <= _count; i++) {
      float pos = map(i, 0, _count, -box, box);
      // ZX-grid @ Y=0
      line(pos, 0, -box, pos, 0, box);
      line(-box, 0, pos, box, 0, pos);
      // YZ-grid @ X=0
      line(0, pos, -box, 0, pos, box);
      line(0, -box, pos, 0, box, pos);
      // XY-grid @ Z=0
      line(pos, -box, 0, pos, box, 0);
      line(-box, pos, 0, box, pos, 0);
    }
  }
  
  // draw audio level waveforms in top window as song progresses
  void drawAudioLevels(float Llev, float Rlev, int pos, int len) {   
    // level = RMS (root-mean-square) of whole buffer array
    // auto-scale output by max levels seen so far
    levSc = max(max(levL)*1.1,max(levR)*1.1,levSc);
    float posx = map(pos,0,len,0,W1);
    levL[int(posx)] = max(levL[int(posx)],Llev);
    levR[int(posx)] = max(levR[int(posx)],Rlev);  
  }

  void drawPPSWave(float[] xIn, float sc, color c, float sw) {
    float c1,c2,c3;         // trying 3D images
    tau = min(tau,ND2);     // timestep for pseudo-derivative
    int imax;
    if ( xIn != null ) {
      imax = max(0,min(xIn.length-tau*2, N-tau*2));
      noFill();               // (use smaller tau for greater detail)
      stroke(c);
      strokeWeight(sw);
      curveTightness(crvTs); // 0.5 orig, 0.0 default
      beginShape();
      for ( int i=0; i < imax; i++) { ;
        c1 = xIn[i];
        c2 = xIn[i+tau]; 
        c3 = xIn[i+tau*2]; 
        curveVertex((c1)*sc, (c2)*sc, (c3)*sc);
      }
      endShape();
    }
  }
  
  void drawPPSData(float[] LData, float[] RData) {
    // Guru visualizer: discrete (pseudo) phase-space rendering
    float pScale = 150*D/float(M)/levSc;  // logarithmic scale + tweak factor
    // Right channel data in Red
    if (RData != null) {
      drawPPSWave(RData, pScale*2, PRed, 1.5);
    }
    // Left channel data in Yellow
    if (LData != null) {
      drawPPSWave(LData, pScale*2, PYellow, 1.5);
    }
    // Sum of both channels in White
    if (LData != null && RData != null) {
      for ( int i=0; i < N; i++ ) {
        LRData[i] = LData[i] + RData[i];
      }
      drawPPSWave(LRData, pScale, PWhite, 1.5);
    }
  }

  // draw FFT waveforms in given scale, color, and stroke width
  void drawFFTWave(float fScale, color c, float sw, boolean logscl) {
    int imax; 
    float box2 = box*2;
    float s;
    float x1,x2,y1,y2,z1,z2;
    //PVector band = new PVector();
  
    imax = max(0,min(xS.length, NFR));
    noFill();
    stroke(c);
    strokeWeight(sw);
    // curveTightness parameter tuned for sharp peaks, no loops
    curveTightness(crvTsFFT);
    beginShape();
    // start at 1 to skip origin bug
    //curveVertex(W2,yAxis);
    for( int i = 0; i <= imax ; i++) {
      s = float(i);
      if (logscl) { // log10 scale
        z1 = map( max(log(s)/log(10),0), 0, log(NFR)/log(10), -box, box );
        z2 = map( max(log(s+1)/log(10),0), 0, log(NFR)/log(10), -box, box );
      } else { // linear scale
        z1 = map( s, 0, imax, -box, box  );
        z2 = map( s+1, 0, imax, -box, box );
      }    
      x1 = map( xR[i], 0, fScale, 0, box2 );
      x2 = map( xR[i+1], 0, fScale, 0, box2 );
      y1 = map( xI[i], 0, fScale, 0, box2 );
      y2 = map( xI[i+1], 0, fScale, 0, box2 );
      curveVertex(x1,y1,z1);
      curveVertex(x2,y2,z2);    
    }
    endShape();     
  }
  
  // scale and color FFT waveforms + errors, as given by FFT(right=real,left=imag)
  void drawFFTData(float[] right, float[] left, boolean logscl) { //, float[] Slib, float[] Serr) {
    if (right != null && left != null) {
      fftLib.forward(right,left);
      xR = fftLib.getSpectrumReal();
      xI = fftLib.getSpectrumImaginary();
      // dynamic scale factor
      frScale = max(max(max(xR),max(xI)),1.0)*0.9;  
      wScale = frScale*3;
      // HIGH-RES full-spectrum data in purple 
      if (xR != null && xI != null) {
        drawFFTWave(frScale, FPurple, 1.5, logscl);
      }
    }
  }
  
  void displayCmds(int _tr) {
    stroke(255);
    strokeWeight(1);
    text("Press spacebar to start/pause: ", 20, 20 );
    text((samples[_tr]+", "+B+", "+int(S)+" Hz"), 20, 40 ); //, Fc="+int(Fc)+" Hz") 
    text("tau = "+tau, 20, 60);
  }
}
  
