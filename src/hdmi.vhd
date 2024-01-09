library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use STD.textio.all;
use ieee.std_logic_textio.all;
use work.palette.all;


entity hdmi is
  port (
    -- Global control --
    clk_i       : in  std_logic; -- global clock, rising edge
    rdy_i       : in  std_logic; -- global clock, rising edge
    rstn_i      : in  std_logic; -- global reset, low-active, async
    tmds_clk_p_o: out std_logic;
    tmds_clk_n_o: out std_logic;
    tmds_data_p_o: out std_logic_vector(2 downto 0);
    tmds_data_n_o: out std_logic_vector(2 downto 0);
    -- ram access
    rd_o        : out std_logic;
    vid_addr_o      : out std_logic_vector(15 downto 0);
    vid_data_i      : in std_logic_vector(7 downto 0);
    vattrib_addr_o      : out std_logic_vector(9 downto 0);
    vattrib_data_i      : in std_logic_vector(7 downto 0)
  );
end entity;


architecture basic of hdmi is
    -- HDMI signals and constants
    -- see: https://projectf.io/posts/video-timings-vga-720p-1080p/#hd-1280x720-60-hz
    constant PX_WIDTH                : integer := 1280;
    constant PX_FRONT_PORCH          : integer := 110;
    constant PX_SYNC_PULSE           : integer := 40;
    constant PX_BACK_PORCH           : integer := 220;
    constant LINE_HEIGHT             : integer := 720;
    constant LINE_FRONT_PORCH : integer := 5;
    constant LINE_SYNC_PULSE : integer := 5;
    constant LINE_BACK_PORCH : integer := 20;
    -- counters
    signal counter_x : integer range 0 to (PX_WIDTH + PX_FRONT_PORCH + PX_SYNC_PULSE + PX_BACK_PORCH + 1);
    signal counter_y : integer range 0 to (LINE_HEIGHT + LINE_FRONT_PORCH + LINE_SYNC_PULSE + LINE_BACK_PORCH + 1);
    -- out signals
    signal rgb_vs_i: std_logic;
    signal rgb_hs_i: std_logic;
    signal rgb_de_i: std_logic;
    signal rgb_r_i: std_logic_vector(7 downto 0);
    signal rgb_g_i: std_logic_vector(7 downto 0);
    signal rgb_b_i: std_logic_vector(7 downto 0);
    -- DVI TX component created by Gowin
    component DVI_TX_Top
        port (
            I_rst_n: in std_logic;
            I_rgb_clk: in std_logic;
            I_rgb_vs: in std_logic;
            I_rgb_hs: in std_logic;
            I_rgb_de: in std_logic;
            I_rgb_r: in std_logic_vector(7 downto 0);
            I_rgb_g: in std_logic_vector(7 downto 0);
            I_rgb_b: in std_logic_vector(7 downto 0);
            O_tmds_clk_p: out std_logic;
            O_tmds_clk_n: out std_logic;
            O_tmds_data_p: out std_logic_vector(2 downto 0);
            O_tmds_data_n: out std_logic_vector(2 downto 0)
        );
    end component;

    -- screen details
    constant zx_screen_res_x   : integer := 256;
    constant zx_screen_res_y   : integer := 192;
    constant zx_screen_scale   : integer := 3;
    constant zx_screen_offset   : integer := 100;
    signal zx_screen_counter_x : integer range 0 to (PX_WIDTH + PX_FRONT_PORCH + PX_SYNC_PULSE + PX_BACK_PORCH + 1)/zx_screen_scale;
    signal zx_screen_counter_y : integer range 0 to (PX_WIDTH + PX_FRONT_PORCH + PX_SYNC_PULSE + PX_BACK_PORCH + 1)/zx_screen_scale;
    -- reset handling
    signal rdy_internal   : std_logic := '0';

begin


hdmi0: DVI_TX_Top
    port map (
        I_rst_n => rstn_i,
        I_rgb_clk => clk_i,
        I_rgb_vs => rgb_vs_i,
        I_rgb_hs => rgb_hs_i,
        I_rgb_de => rgb_de_i,
        I_rgb_r => rgb_r_i,
        I_rgb_g => rgb_g_i,
        I_rgb_b => rgb_b_i,
        O_tmds_clk_p => tmds_clk_p_o,
        O_tmds_clk_n => tmds_clk_n_o,
        O_tmds_data_p => tmds_data_p_o,
        O_tmds_data_n => tmds_data_n_o
    );



-- takes care of synchronisation signals
process (clk_i)
    variable scale_counter_x : integer range 0 to zx_screen_scale;
    variable scale_counter_y : integer range 0 to zx_screen_scale;
    -- screen
    variable addr_scr      : std_logic_vector(15 downto 0);
    variable tmp_counter_x : std_logic_vector(7 downto 0);
    variable tmp_counter_y : std_logic_vector(7 downto 0);
    variable tmp_zx_screen_counter_x : integer range 0 to (PX_WIDTH + PX_FRONT_PORCH + PX_SYNC_PULSE + PX_BACK_PORCH + 1)/zx_screen_scale;
    variable tmp_zx_screen_counter_y : integer range 0 to (PX_WIDTH + PX_FRONT_PORCH + PX_SYNC_PULSE + PX_BACK_PORCH + 1)/zx_screen_scale;
begin
    if (rising_edge(clk_i)) then
        if (rstn_i = '0') then
                counter_y <= 0;
                counter_x <= 0;
                scale_counter_x := 0;
                scale_counter_y := 0;
                rdy_internal <= '0';
        else
            if (rdy_i = '1') then
                rdy_internal <= '1';
                if counter_x = (PX_WIDTH + PX_FRONT_PORCH + PX_SYNC_PULSE + PX_BACK_PORCH - 1) then
                    counter_x <= 0;
                    zx_screen_counter_x <= 0;
                    tmp_zx_screen_counter_x := 0;
                    scale_counter_x := 0;
                    if counter_y = (LINE_HEIGHT + LINE_FRONT_PORCH + LINE_SYNC_PULSE + LINE_BACK_PORCH - 1) then
                        counter_y <= 0;
                        zx_screen_counter_y <= 0;
                        tmp_zx_screen_counter_y := 0;
                        scale_counter_y := 0;
                    else
                        counter_y <= counter_y + 1;
                        -- additional counter for screen scaling
                        scale_counter_y := scale_counter_y + 1;
                        if (scale_counter_y = zx_screen_scale) then
                            scale_counter_y := 0;
                            zx_screen_counter_y <= zx_screen_counter_y + 1;
                            tmp_zx_screen_counter_y := tmp_zx_screen_counter_y + 1;
                        end if;

                    end if;
                else
                    counter_x <= counter_x + 1;
                    -- additional counter for screen scaling
                    scale_counter_x := scale_counter_x + 1;
                    if (scale_counter_x = zx_screen_scale) then
                        scale_counter_x := 0;
                        zx_screen_counter_x <= zx_screen_counter_x + 1;
                        tmp_zx_screen_counter_x := tmp_zx_screen_counter_x + 1;
                    end if;

                end if;

                if counter_x >= (PX_WIDTH + PX_FRONT_PORCH) AND counter_x < (PX_WIDTH + PX_FRONT_PORCH + PX_SYNC_PULSE) then
                    rgb_hs_i <= '1';
                else
                    rgb_hs_i <= '0';
                end if;

                if counter_y >= (LINE_HEIGHT + LINE_FRONT_PORCH) AND counter_y < (LINE_HEIGHT + LINE_FRONT_PORCH + LINE_SYNC_PULSE) then
                    rgb_vs_i <= '1';
                else
                    rgb_vs_i <= '0';
                end if;

                if (tmp_zx_screen_counter_x >= zx_screen_offset) and (tmp_zx_screen_counter_x < (zx_screen_res_x + zx_screen_offset)) and
                       (tmp_zx_screen_counter_y < zx_screen_res_y)
                then
                    tmp_counter_x := std_logic_vector(to_unsigned(tmp_zx_screen_counter_x-zx_screen_offset,8));
                    tmp_counter_y := std_logic_vector(to_unsigned(tmp_zx_screen_counter_y,8));
                    addr_scr := "000" & tmp_counter_y(7) &
                                        tmp_counter_y(6) &
                                        tmp_counter_y(2) &
                                        tmp_counter_y(1) &
                                        tmp_counter_y(0) &
                                        tmp_counter_y(5) &
                                        tmp_counter_y(4) &
                                        tmp_counter_y(3) &
                                        tmp_counter_x(7 downto 3);
                    report "This is x " & to_hstring(tmp_counter_x) & " and y " & to_hstring(tmp_counter_y) &
                    " addr: " & to_hstring(addr_scr) & " bit " & to_hstring(tmp_counter_x(2 downto 0)) & "scale cnt x" & 
                    integer'image(scale_counter_x) & "scale cnt y" & integer'image(scale_counter_y);

                    vattrib_addr_o <= tmp_counter_y(7 downto 3) & tmp_counter_x(7 downto 3);
                    -- need to add optimalisation like not reading addres which is already fetched
                    -- NOTE: same can be done for lines, we could create buffer with all needed data fetched in first line
                    -- fetch data at first bit                    
                    if (scale_counter_x = 0) and (tmp_counter_x(2 downto 0) = "000") and  (scale_counter_y = 0)  then
                        rd_o <= '0';
                        vid_addr_o <= addr_scr;
                        
                    else
                        -- we do not need to read anything
                        rd_o <= '1';
                    end if;
                else
                    rd_o <= '1';
                end if;


            end if;
        end if;
    end if;

end process;


process (clk_i)
    variable addr_scr      : std_logic_vector(15 downto 0);
    variable tmp_char : std_logic_vector(7 downto 0);
    variable tmp_bit : std_logic;
    variable col: std_logic_vector(7 downto 0);
    variable ink: std_logic_vector(2 downto 0);
    variable bright: std_logic;
    variable paper: std_logic_vector(2 downto 0);

    -- get rid of this
    variable tmp_counter_x : std_logic_vector(7 downto 0);
    type line_t  is array (natural range 31 downto 0) of std_logic_vector(07 downto 0);
    variable line_buffer : line_t := (others => (others => '0'));
    variable y_scale_cnt : integer range 0 to zx_screen_scale := 0;

begin
    if (falling_edge(clk_i)) then
        if (rstn_i = '0') then
            rgb_de_i <= '0';
            rgb_g_i <= (others => '0');
            rgb_b_i <= (others => '0');
            rgb_r_i <= (others => '0');
            y_scale_cnt := 0;
        else
            if (rdy_i = '1') and (rdy_internal = '1') then
                -- ensure that we are working at visible screen part
                if (counter_x < PX_WIDTH) and (counter_y < LINE_HEIGHT) then
                    rgb_de_i <= '1';
                    -- we will not fill whole screen, we are taking
                    -- some part of it
                    if (zx_screen_counter_x >= zx_screen_offset) and (zx_screen_counter_x < (zx_screen_res_x + zx_screen_offset)) and
                       (zx_screen_counter_y < zx_screen_res_y)
                    then
                        -- next line: think how to improve it
                        tmp_counter_x := std_logic_vector(to_unsigned(zx_screen_counter_x-zx_screen_offset,8));
                        -- due to optimalisation
                        -- not every time we need to read data
                        -- scaling 3 gives 3 same reads
                        if (rd_o = '0') then
                            tmp_char := vid_data_i;
                            if (y_scale_cnt = 0) then
                                line_buffer(to_integer(unsigned(tmp_counter_x(7 downto 3)))) := vid_data_i;
                            end if;
                        elsif (y_scale_cnt /= 0) and (y_scale_cnt /= zx_screen_scale) then
                                -- take data from buffer
                                report "taking from line buffer";
                                tmp_char := line_buffer(to_integer(unsigned(tmp_counter_x(7 downto 3))));
                        end if;


                        tmp_bit := tmp_char(7-to_integer(unsigned(tmp_counter_x(2 downto 0))));
                        report "PutPixel [x=" & integer'image(zx_screen_counter_x-zx_screen_offset) & ",y=" & integer'image(zx_screen_counter_y) & "]=" & std_logic'image(tmp_bit) &
                               " addr=" & to_hstring(vid_addr_o);
                        col := vattrib_data_i;
                        ink := col(2 downto 0); 
                        paper := col(5 downto 3); 
                        bright := col(6);

                      -- add color handling
                      if (tmp_bit = '1') then
                          if (bright = '0') then
                              rgb_r_i <= palette_0(to_integer(unsigned(ink)))(7 downto 0); 
                              rgb_g_i <= palette_0(to_integer(unsigned(ink)))(15 downto 8); 
                              rgb_b_i <= palette_0(to_integer(unsigned(ink)))(23 downto 16);
                          else
                              rgb_r_i <= palette_1(to_integer(unsigned(ink)))(7 downto 0); 
                              rgb_g_i <= palette_1(to_integer(unsigned(ink)))(15 downto 8); 
                              rgb_b_i <= palette_1(to_integer(unsigned(ink)))(23 downto 16);
                          end if; 
                      else
                          if (bright = '0') then
                              rgb_r_i <= palette_0(to_integer(unsigned(paper)))(7 downto 0); 
                              rgb_g_i <= palette_0(to_integer(unsigned(paper)))(15 downto 8); 
                              rgb_b_i <= palette_0(to_integer(unsigned(paper)))(23 downto 16);
                          else
                              rgb_r_i <= palette_1(to_integer(unsigned(paper)))(7 downto 0); 
                              rgb_g_i <= palette_1(to_integer(unsigned(paper)))(15 downto 8); 
                              rgb_b_i <= palette_1(to_integer(unsigned(paper)))(23 downto 16);
                          end if; 
                      end if; 


                        
-- old handling
--                        if (tmp_bit = '0') then
--                            rgb_r_i <= (others => '0');
--                            rgb_g_i <= (others => '0');
--                            rgb_b_i <= (others => '0');
--                        else
--                            rgb_r_i <= (others => '1');
--                            rgb_g_i <= (others => '1');
--                            rgb_b_i <= (others => '1');
--                        end if;
                    else
                        rgb_r_i <= "00000000";
                        rgb_g_i <= "11111111";
                        rgb_b_i <= "00000000";
                    end if;
                else
                    -- increase only once per line to 
                    -- indicate next zx line
                    -- TODO: what about next frame - this counter needs to be reseted
                    if (counter_x = PX_WIDTH) then
                        if (y_scale_cnt /= zx_screen_scale-1) then
                            y_scale_cnt := y_scale_cnt + 1;
                            report "increase y_scale_cnt";
                        else
                            y_scale_cnt := 0;
                            report "reset y_scale_cnt";
                        end if;
                    end if;
                    -- no color data will be sent
                    rgb_de_i <= '0';
                    rgb_g_i <= (others => '0');
                    rgb_b_i <= (others => '0');
                    rgb_r_i <= (others => '0');
                end if;
            end if;
        end if;
    end if;
end process;

end architecture;
