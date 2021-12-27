/**
  * cFFT.windows: adapted from built-in Processing minim FFT libraries and
  * - https://github.com/BenTommyE/Ben-FFT/presentation.pde 
  * - https://www.local-guru.net/blog/2019/1/22/processing-sound-visualizer-explained  
  * - 
 */ 

class cmWin {
  // FFT parameters
  int N;
  float S;
  int B;
  int D;
  int M;
  float T;
  // sub-window widths ~= W/2
  int W1;
  int W2; 
  // sub-window heights, x-axes
  int H1;   
  int H2;
  int H3;
  int H12;
  int H21;
  int H22;
  // audio rendering data
  float[] levL;
  float[] levR;
  // freq rendering data
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
  cmWin (int _W, float _H, int _N) {
    N = _N;
    B = N;
    W1 = _W/2;
    W2 = _W-W1; 
    // sub-window heights, zero-axes, etc
    H1 = 30;   
    H2 = int(_H/3);
    H3 = 2*H2+H1;
    H12 = H1*2;
    H21 = H2-H1;
    H22 = H2-H12;
    // limit buffer of audio/freq bands to render
    Nmin = 16;   // lowest allowable value of N that doesn't slow down rendering
    ND2 = N/2;
    NBR = N;
    NFRscale = 1.0; // 0.8; // crop off top 20% by default
    NFR = int(ND2*NFRscale);
    // running display of R/L channel levels
    levL = new float[W1+1];
    levR = new float[W1+1];
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
  
  void drawGrid(int count, int _grid, color c) {
    noFill();
    stroke(c); 
    float size = (count) * _grid/2.0;
    for (int i = 0; i <= count; i++) {
      float pos = map(i, 0, count, -size, size);
      // ZX-grid @ Y=0
      line(pos, 0, -size, pos, 0, size);
      line(-size, 0, pos, size, 0, pos);
      // YZ-grid @ X=0
      line(0, pos, -size, 0, pos, size);
      line(0, -size, pos, 0, size, pos);
      // XY-grid @ Z=0
      line(pos, -size, 0, pos, size, 0);
      line(-size, pos, 0, size, pos, 0);
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
    //println("draw PPS waveform");
    float c1,c2,c3;         // trying 3D images
    tau = min(tau,ND2);     // timestep for pseudo-derivative
    noFill();               // (use smaller tau for greater detail)
    stroke(c);
    strokeWeight(sw);
    curveTightness(crvTs); // 0.5 orig, 0.0 default
    beginShape();
    for ( int i=0; i < N-tau*2; i++) { ;
      c1 = xIn[i];
      c2 = xIn[i+tau]; 
      c3 = xIn[i+tau*2]; 
      curveVertex((c1)*sc, (c2)*sc, (c3)*sc);
    }
    endShape();
  }
  
  void drawPPSData(float[] LData, float[] RData, float[] LRData) {
    // Guru visualizer: discrete (pseudo) phase-space rendering
    //translate(width/2, height/2, 0);
    // rotate 45 deg. CW for perpendicular axes: X = amplitude, Y = dX/dt
    //rotate(-PI/4);
    float pScale = 150*D/float(M)/levSc;  // logarithmic scale + tweak factor
    // Right channel data in Red
    drawPPSWave(RData, pScale*2, PRed, 1.5);
    // Left channel data in Yellow
    drawPPSWave(LData, pScale*2, PYellow, 1.5);
    // Sum of both channels in White
    drawPPSWave(LRData, pScale, PWhite, 1.5);
  }

  void displayCmds(int _tr, String txt) {
    stroke(255);
    strokeWeight(1);
    text("Press spacebar to start/pause: ", 20, H1 );
    text((tracks[_tr]+", "+B+", "+int(S)+" Hz"), 20, H1+20 ); //, Fc="+int(Fc)+" Hz") 
    text("tau = "+tau, 20, H1+40);
  }
}
  
