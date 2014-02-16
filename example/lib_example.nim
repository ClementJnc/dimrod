import dimrod

const 
    config_unit : TBasicUnitsConf = (@["m", "kg", "s"],@[(-1,2), (-1,1), (-2,2)])
    uname_config = ("T", "v", "nodim")
    alias_config : TAliasConf= (@["N", "Pa", "J"], @[@[1,1,-2], @[-1,1,-2], @[2,1,-2]])


init_unit(config_unit, uname_config, alias_config)
