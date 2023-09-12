module harenae.update.CellUpdater;

import harenae.all;

/** 
 * https://en.wikipedia.org/wiki/Falling-sand_game
 */
final class CellUpdater {
public:
    this(uint2 size) {
        this.size = size;
        this.rng = new RandomBuffer(1024);
        this.sand = new Sand(size, &coinToss);
    }
    /** 
     * TODO - split this into partial updates in a secondary array.
     */
    void update(uint[] cells) {
        //cells[] = 2;

        //cells[10 + 10*size.width] = 3;

        enum X = 600;
        enum Y = 200;

        if(numUpdates == 0) {

            // water
            foreach(y; Y..Y+100) {
                foreach(x; X-100..X) {
                    cells[x + y*size.width] = CellType.WATER;
                }
            }

            // wall
            foreach(y; Y+50..Y+200) {
                foreach(x; X-190..X-180) {
                    cells[x + y*size.width] = CellType.ROCK;
                }
                foreach(x; X+160..X+170) {
                    cells[x + y*size.width] = CellType.ROCK;
                }
            }
            // floor
            foreach(y; Y+200..Y+210) {
                foreach(x; X-190..X+170) {
                    cells[x + y*size.width] = CellType.ROCK;
                }
            }

        } else if(numUpdates == 200) {
            // sand
            foreach(y; Y..Y+100) {
                foreach(x; X..X+100) {
                    cells[x + y*size.width] = CellType.SAND;
                }
            }
        } else {
            //fallingSandMethod(cells);
            //sandAppletMethod(cells);

            sand.update(cells);
        }
        numUpdates++;
    }
private:
    uint2 size;
    ulong numUpdates;
    uint[] tempCells;
    uint updatedFlipFlop;

    bool flipFlop;
    RandomBuffer rng;

    Sand sand;

    enum UPDATED_BIT = (1<<31).as!uint;

    bool coinToss() {
        return rng.next() < 0.5f;
    }

    void fallingSandMethod(uint[] cells) {
        int w = size.x;
        int h = size.y;
        
        flipFlop = !flipFlop;
        updatedFlipFlop ^= UPDATED_BIT;

        void _processCell(int x, int y) {
            int i = x+y*w;

            if (cells[i] == CellType.SAND) {  

                bool okDown = y<h-1 && cells[i+w]==0;   

                if(okDown) {   
                    cells[i] = 0; 
                    cells[i+w] = CellType.SAND; 
                } else {
                    int dir = x==0 ? 1 : 
                              x==w-1 ? -1 : 
                              coinToss() ? -1 : 1; 
                    bool okDownDiag = y<h-1 && cells[i+dir + w]==0;    
                    if (okDownDiag) { 
                        cells[i] = 0; 
                        cells[i+dir+w] = CellType.SAND; 
                    } 
                }
            }
        }

        void _processCellLiquid(int x, int y) {
            int i = x+y*w;

            uint cellType = cells[i] & 0xff;

            if (cellType == CellType.SAND) { 

                if((cells[i] & UPDATED_BIT) == updatedFlipFlop) {
                    // Already updated
                    return;
                } 

                uint below = cells[i+w];
                uint belowType = below & 0xff;

                bool emptyOrLiquidDown = y<h-1 && (belowType==0 || belowType >= 100);  

                if(emptyOrLiquidDown) {
                    cells[i] = below; 
                    cells[i+w] = CellType.SAND | updatedFlipFlop; 
                } else {
                    int dir = x==0 ? 1 : 
                              x==w-1 ? -1 : 
                              coinToss() ? -1 : 1; 
                    uint below2 = cells[i+dir+w];
                    uint belowType2 = below2 & 0xff;
                    bool emptyOrLiquid = y<h-1 && (belowType2==0 || belowType2 >= 100);   
                    if(emptyOrLiquid) {
                        cells[i] = below2; 
                        cells[i+dir+w] = CellType.SAND | updatedFlipFlop; 
                    } else {
                        // probaboly not required

                        // it didn't move. mark it as updated
                        cells[i] ^= updatedFlipFlop; 
                    }
                }  

            } else if(cellType == CellType.WATER) {  

                if((cells[i] & UPDATED_BIT) == updatedFlipFlop) {
                    // Already updated
                    return;
                } 

                uint belowType = cells[i+w] & 0xff;
                bool okDown = y<h-1 && belowType==0;   

                if(okDown) {   
                    cells[i] = 0; 
                    cells[i+w] = CellType.WATER | updatedFlipFlop; 
                } else {
                    int dir = x==0 ? 1 : 
                              x==w-1 ? -1 : 
                              coinToss() ? -1 : 1; 

                    uint belowType2 = cells[i+dir+w] & 0xff;

                    bool okDownDiag = y<h-1 && belowType2==0;    
                    if (okDownDiag) { 
                        cells[i] = 0; 
                        cells[i+dir+w] = CellType.WATER | updatedFlipFlop; 
                    } else {
                        // probaboly not required

                        // it didn't move. mark it as updated
                        cells[i] ^= updatedFlipFlop; 
                    }
                }
            } 

        }

        for (int y = h - 1; y >= 0; y--) {
            if(flipFlop) {
                for (int x = 0; x < w; x++) {
                    //_processCell(x, y);
                    _processCellLiquid(x, y);
                }
            } else {
                for (int x = w-1; x >= 0; x--) {    
                    //_processCell(x, y);
                    _processCellLiquid(x, y);
                }
            }
        }
    }

    /** 
     * Taken from SandApplet
     *
     * Cell structure: (uint)
     *  - (x,y implied)
     *  - 8 bits = type
     *  - 8 bits = direction (NONE, LEFT, RIGHT)
     *  - 15 bits = momentum
     *  - 1 bit updated flag
     *
     */
    void sandAppletMethod(uint[] cells) {
        int w = size.x;
        int h = size.y;

        uint MOMENTUM = 6;      // lower=lower

        enum : ubyte {
            NONE = 0, LEFT, RIGHT
        }

        enum MAX_MOMENTUM = 1;
        

        updatedFlipFlop ^= UPDATED_BIT;

        // Iterate from the bottom to the top
        for(int y = h-1; y >= 0; y--) {
            foreach(x; 0..w) {
                uint i    = x + y*w;
                uint cell = cells[i];

                if(cell == 0) {
                    continue;   
                }
                if((cell & UPDATED_BIT) == updatedFlipFlop) {
                    continue;
                }
                
                uint type = cell & 0xff;
                uint momentum = (cell >>> 16) & 0b01111111_11111111;
                uint direction = ((cell >>> 8) & 0xff);

                uint2 newPos = uint2(x,y);
                uint newMomentum = momentum;
                auto newDirection = direction;

                void setMomentum(int m) {
                    if(m < 0) m = 0; else if(m > MAX_MOMENTUM) m = MAX_MOMENTUM;
                    newMomentum = m;
                }
                void increaseMomentum() {
                    setMomentum(momentum+1);
                }
                void reduceMomentum() {
                    setMomentum(momentum-1);
                }
                void setDirection(uint d) {
                    newDirection = d;
                }

                // 
                // O@O
                // OOO
                //

                bool okDown = y<h-1 && cells[i+w]==0;

                if(okDown) {
                    newPos.y++;
                    increaseMomentum();
                } else {
                    bool okLeft = x>0 && cells[i-1]==0;
                    bool okRight = x<w-1 && cells[i+1]==0;
                    bool okDownLeft = okLeft && y<h-1 && cells[i+w-1]==0;
                    bool okDownRight = okRight && y<h-1 && cells[i+w+1]==0;

                    if(okDownLeft && okDownRight) {
                        if(direction==RIGHT) {
                            newPos.x++;
                            increaseMomentum();
                        } else if(direction==LEFT) {
                            newPos.x--;
                            increaseMomentum();
                        } else {
                            // direction == NONE
                            if(coinToss()) {
                                newPos.x++;
                                setDirection(RIGHT);
                            } else {
                                newPos.x--;
                                setDirection(LEFT);
                            }
                            setMomentum(1);
                        }
                    } else if(okDownLeft) {
                        newPos.x--;
                        if(direction==LEFT) increaseMomentum();
                        else setMomentum(1);

                        setDirection(LEFT);
                    } else if(okDownRight) {
                        newPos.x++;
                        if(direction==RIGHT) increaseMomentum();
                        else setMomentum(1);

                        setDirection(RIGHT);


                    } else if(okLeft && okRight) {

                        if(direction==NONE || momentum==0) {
                            setMomentum(0);
                            setDirection(NONE);
                        } else {
                            reduceMomentum();
                            if(direction==LEFT) {
                                newPos.x--;
                            } else {
                                newPos.x++;
                            }
                        }
                    } else if(okLeft && direction==LEFT && momentum > 0) {
                        newPos.x--;
                        reduceMomentum();
                    } else if(okRight && direction==RIGHT && momentum > 0) {
                        newPos.x++;
                        reduceMomentum();
                    } else {
                        setMomentum(0);
                        setDirection(NONE);
                    }
                }

                cells[newPos.x + newPos.y*w] = updatedFlipFlop | 
                                               (newMomentum << 16) |
                                               (newDirection << 8) | 
                                               type;

                if(newPos != uint2(x,y)) {
                    // the cell moved
                    cells[x + y*w] = 0;
                }
            }
        }
    }
}