module harenae.update.Water;

import harenae.all;

/** 
  Cell:
    - 8 bits: type
    - 16 bits: density/256 (1 for normal, 2 for twice normal which needs to be equalised)
               This means that each cell be hold a maximum of 256 * normal density
 
  For each SAND cell:
    If below is liquid:
      Move down as normal.
      Set displaced volume to the volume that was in the below cell.
 
      Cell:
        [ 8] type (0..255)
        [10] current volume (0..1023)
        [10] volume displaced in this pass (0..1023)
        [ 3] *unused
        [ 1] updated flag
 
    Water movement pass 1:
      If cell is WATER:
    
        If below is empty -> move water down

        If left/right are empty -> move 50% of the water volumn to left and right

        If volume > 100 -> Try to displace some

      If cell is SAND:
        If there is displaced volume in the cell, try to move it down or to either side.
        (Use updated flag to prevent discplaced water from flowing more than 1 cell per pass)
 
      If cell is ROCK -> do nothing  

    Displaced water pass 2: 

      If cell has displaced volume:
       

  
  TODO - Different types of liquid. Water should displace into oil for example but
         this would not be possible at the moment. Also, oil is slightly less dense than water
         and should rise to the surface.
 */
final class Water {
public:
    this(uint2 size, bool delegate() coinToss) {
        this.size = size;
        this.w = size.x;
        this.h = size.y;
        this.coinToss = coinToss;
    }
    void update(uint[] cells) {
        updateWater(cells);
        balancePass(cells);
    }
private:
    enum UPDATED_BIT = (1<<31).as!uint;
    uint2 size;
    int w;
    int h;
    bool delegate() coinToss;
    bool flipFlop;
    uint updatedFlipFlop;

    /**
     *  Spread any excess density to neighbouring cells
     */
    void balancePass(uint[] cells) {

    }
    /**
     *  Move cells if possible
     */
    void updateWater(uint[] cells) {

        updatedFlipFlop ^= UPDATED_BIT;
        
        void processCell(int x, int y) {
            int i     = x+y*w;
            uint cell = cells[i]; 

            // Move WATER down if below is WATER or EMPTY

            if ((cell & 0xff) == CellType.WATER) { 

                if((cell & UPDATED_BIT) == updatedFlipFlop) {
                    // Already updated
                    return;
                } 

                uint volume    = (cell >>> 8) & 1023;
                uint displaced = (cell >>> 18) & 1023;
                auto belowType = cells[i+w] & 0xff;
                bool okDown    = y<h-1;   

                if(okDown && belowType == CellType.AIR) {   
                    cells[i] = 0; 
                    cells[i+w] = CellType.WATER | (volume << 8) | (displaced << 18) | updatedFlipFlop; 
                } else if(okDown && belowType == CellType.WATER) {
                    cells[i] = 0; 

                    uint belowVolume    = (cells[i+w] >>> 8) & 1023;
                    uint belowDisplaced = (cells[i+w] >>> 18) & 1023;

                    uint newVolume = volume + belowVolume;

                    if(newVolume > 100) {
                        displaced += (newVolume-100);
                        volume = 100;
                    } else {
                        volume = newVolume;
                    }
                    displaced += belowDisplaced;

                    cells[i+w] = CellType.WATER | (volume << 8) | (displaced << 18) | updatedFlipFlop; 
                } else {
                    bool okLeft = x > 0;
                    bool okRight = x < w-1;
                    
                    if(okLeft && okRight) {
                        auto leftType = cells[i-1] & 0xff;
                        auto rightType = cells[i+1] & 0xff;

                        if(leftType == CellType.AIR && rightType == CellType.AIR) {
                            // spread volume left and right evenly
                        } else if(leftType == CellType.WATER && rightType == CellType.WATER) {

                        } else {
                            
                        }
                    }

                    // if (okDownDiag) { 
                    //     cells[i] = 0; 
                    //     cells[i+dir+w] = CellType.SAND; 
                    // } 
                }
            }
        }

        for (int y = h - 1; y >= 0; y--) {
            if(flipFlop) {
                for (int x = 0; x < w; x++) {
                    processCell(x, y);
                }
            } else {
                for (int x = w-1; x >= 0; x--) {    
                    processCell(x, y);
                }
            }
        }
    }
}
